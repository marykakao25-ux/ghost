#Requires -Version 5.1
<#
.SYNOPSIS
Захват задачи по схеме A+B (лок-ветка claim/* + лиз-файл в tasks/claims/).

.DESCRIPTION
Порядок шагов важен: сначала берётся жёсткий лок через уникальную ветку
claim/T-XXXX (его обеспечивает сам git-сервер), только потом пишется
человекочитаемый лиз-файл в main. При любом отказе захват снимается
целиком, поэтому «залипших» локов не остаётся.

.EXAMPLE
pwsh -File scripts/agent/claim.ps1 -Task T-0012 -Owner cline

.EXAMPLE
pwsh -File scripts/agent/claim.ps1 -Task T-0012 -Owner cline -Takeover
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Task,
    [Parameter(Mandatory)][string]$Owner,
    [switch]$Takeover,
    [switch]$IgnorePathConflicts,
    [int]$LeaseHours = 4
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AgentCommon.ps1')

function Fail {
    param([string]$Message)
    Write-Err $Message
    exit 1
}

function Remove-ClaimRef {
    param([string]$Ref)
    if (Remove-RemoteRef -Ref $Ref) { Write-Ok "Лок $Ref снят." }
    else { Write-Warn "Не удалось снять $Ref — снимите вручную: git push origin --delete $Ref" }
}

# ---------------------------------------------------------------- шаг 1 ----
Write-Step '1. Синхронизация с origin и проверка рабочего дерева'
Set-GitIdentityIfMissing
if (-not (Test-CleanWorktree)) {
    Fail 'Рабочее дерево грязное. Закоммитьте или уберите изменения (git status) и повторите.'
}
Invoke-Git -Arguments @('fetch', '--prune', 'origin') | Out-Null

# ---------------------------------------------------------------- шаг 2 ----
$claimRef = Get-ClaimBranch -Task $Task
Write-Step "2. Проверка жёсткого лока $claimRef (слой B)"
if (Test-RemoteBranch -Name $Task -Prefix 'claim') {
    if (-not $Takeover) {
        Fail "Лок $claimRef уже существует — задачу кто-то держит.`n" +
        "   Живой он или нет, покажет: git show origin/$claimRef --stat`n" +
        "   Снять просроченный лок: pwsh -File scripts/agent/claim.ps1 -Task $Task -Owner $Owner -Takeover"
    }
    Write-Warn "Лок $claimRef уже есть, режим -Takeover: старый лок будет снят после проверок."
}

# ---------------------------------------------------------------- шаг 3 ----
Write-Step "3. Проверка рабочей ветки task/$Task-*"
$taskBranches = @(Get-RemoteBranchNames -Pattern '*' | Where-Object {
        (Get-BranchPrefix -Name $_) -eq 'task' -and (Get-RemoteBranchSuffix -Name $_) -like "$Task-*"
    })
if ($taskBranches.Count -gt 0 -and -not $Takeover) {
    Fail ("Ветка работы уже существует: " + ($taskBranches -join ', ') + "`n" +
        "   Значит работа велась и не была закрыта. Проверьте статус задачи:`n" +
        "   pwsh -File scripts/agent/status.ps1`n" +
        "   Если ветка брошена — запускайте с -Takeover.")
}
if ($taskBranches.Count -gt 0) {
    Write-Warn "Найдены ветки работы: $(($taskBranches -join ', ')). Будут переиспользованы после takeover."
}

# ---------------------------------------------------------------- шаг 4 ----
Write-Step '4. Обновление main'
$startBranch = Get-CurrentBranch
Invoke-Git -Arguments @('switch', 'main') | Out-Null
Invoke-Git -Arguments @('pull', '--ff-only', 'origin', 'main') | Out-Null
Write-Ok "main = $(Invoke-Git -Arguments @('rev-parse', '--short', 'HEAD')).Text"
Initialize-TaskSystem

# ---------------------------------------------------------------- шаг 5 ----
Write-Step "5. Разбор задачи $Task и проверка лиза (слой A)"
$taskPath = Find-Task -Id $Task
$taskData = Read-TaskFile -Path $taskPath
$taskStatus = "$(Get-TaskField -Task $taskData -Key 'status')"
$taskPaths = ConvertTo-StringArray -Value (Get-TaskField -Task $taskData -Key 'paths')

if ($taskStatus -eq 'done') { Fail "Задача $Task уже закрыта (status: done). Возьмите другую." }
if ($taskPaths.Count -eq 0) { Fail "В задаче $Task не задано поле paths — нечем защищаться от конфликтов." }

$claimFile = Join-Path $script:ClaimsDir "$Task.md"
$ownClaim = $null
if (Test-Path -LiteralPath $claimFile) {
    $ownClaim = Read-TaskFile -Path $claimFile
    $claimOwner = "$(Get-TaskField -Task $ownClaim -Key 'owner')"
    $expired = Test-LeaseExpired -Claim $ownClaim

    if (-not $expired -and -not $Takeover) {
        Fail "Задача $Task уже занята: owner=$claimOwner, осталось $(Get-LeaseRemaining -Claim $ownClaim).`n" +
        "   Если владелец пропал: -Takeover (только после проверки tasks/claims/$Task.md)."
    }
    if (-not $expired -and $Takeover) {
        Write-Warn "Перехват ЖИВОГО лиза: owner=$claimOwner, осталось $(Get-LeaseRemaining -Claim $ownClaim). Действие будет записано в историю задачи."
    }
    if ($expired) {
        Write-Warn "Лиз задачи $Task просрочен (owner=$claimOwner) — перехватываем."
    }
}

# ---------------------------------------------------------------- шаг 6 ----
Write-Step '6. Проверка пересечения путей с активными задачами'
$conflicts = @(Get-PathConflicts -Paths $taskPaths -IgnoreTaskIds @($Task))
if ($conflicts.Count -gt 0) {
    if (-not $IgnorePathConflicts) {
        Fail ("Задача $Task пересекается по файлам с уже занятыми задачами:`n" +
            (Format-ConflictList -Conflicts $conflicts) + "`n" +
            "   Возьмите другую задачу или дождитесь освобождения этих файлов.`n" +
            "   Осознанное исключение (например, две задачи обязаны менять project.godot): -IgnorePathConflicts")
    }
    Write-Warn "Пересечения проигнорированы по флагу -IgnorePathConflicts:"
    Write-Host (Format-ConflictList -Conflicts $conflicts) -ForegroundColor Yellow
}
else {
    Write-Ok "Пересечений нет: $(($taskPaths | ForEach-Object { "'$_'" }) -join ', ')"
}

# ------------------------------------------------------- шаг 7.5: лок B ----
if (Test-RemoteBranch -Name $Task -Prefix 'claim') {
    Write-Step "7.5. Перехват существующего лока $claimRef"
    Remove-ClaimRef -Ref $claimRef
}

Write-Step "7.5. Захват жёсткого лока: push $claimRef"
Invoke-Git -Arguments @('commit', '--allow-empty', '-m', "[$Task] claim lock: $Owner") | Out-Null
$lockPush = Invoke-Git -Arguments @('push', 'origin', "HEAD:refs/heads/$claimRef") -AllowFail
if ($lockPush.Code -ne 0) {
    Invoke-Git -Arguments @('reset', '--hard', 'origin/main') -AllowFail | Out-Null
    if ($lockPush.Text -match 'already exists|fetch first|non-fast-forward|rejected') {
        Fail "Лок $claimRef перехватил другой агент (гонка). Задача занята — возьмите другую.`n$($lockPush.Text)"
    }
    Fail "Не удалось создать лок-ветку (нет прав на push?). Захват отменён, ничего не изменено.`n$($lockPush.Text)"
}
Write-Ok "Лок $claimRef закреплён за $Owner."

# ------------------------------------------------------- шаги 8: лиз A ----
Write-Step '8. Запись лиз-файла в main (слой A)'
$leaseUntil = Format-LeaseTime -Value ([datetime]::UtcNow.AddHours($LeaseHours))
$branchName = "task/$Task-$((Split-Path -Leaf $taskPath) -replace "^$Task-", '' -replace '\.md$', '')"

function Write-ClaimFiles {
    # Лиз-файл + обновление статуса задачи. Вызывается повторно после rebase.
    if (-not (Test-Path -LiteralPath $script:ClaimsDir)) {
        New-Item -ItemType Directory -Path $script:ClaimsDir -Force | Out-Null
    }
    $pathsYaml = ($taskPaths | ForEach-Object { "  - $_" }) -join "`n"
    $content = @(
        '---',
        "id: $Task",
        "title: $((Get-TaskField -Task $taskData -Key 'title'))",
        'status: claimed',
        "owner: $Owner",
        "lease_until: $leaseUntil",
        "branch: $branchName",
        'claimed_paths:',
        $pathsYaml,
        "lock_ref: $claimRef",
        '---',
        '',
        "# Лиз задачи $Task",
        '',
        'Файл создан автоматически `scripts/agent/claim.ps1`. Не редактировать руками.',
        'Снимается командой `scripts/agent/release.ps1 -Task ' + $Task + '`.',
        ''
    ) -join "`n"
    Set-Content -LiteralPath $claimFile -Value $content -Encoding UTF8 -NoNewline

    Set-TaskField -Path $taskPath -Key 'status' -Value 'claimed'
    Set-TaskField -Path $taskPath -Key 'owner' -Value $Owner
    Set-TaskField -Path $taskPath -Key 'lease_until' -Value $leaseUntil
    Set-TaskField -Path $taskPath -Key 'branch' -Value $branchName
}

Write-ClaimFiles
Invoke-Git -Arguments @('add', '--', "tasks/claims/$Task.md", "tasks/$((Split-Path -Leaf $taskPath))") | Out-Null

# Проверка «а вдруг кто-то успел» прямо перед коммитом.
$staged = Invoke-Git -Arguments @('diff', '--cached', '--name-only')
$foreign = @($staged.Output | Where-Object { $_ -ne '' -and -not $_.StartsWith("tasks/") })
if ($foreign.Count -gt 0) {
    Invoke-Git -Arguments @('reset', '--hard', 'origin/main') -AllowFail | Out-Null
    Remove-ClaimRef -Ref $claimRef
    Fail "В индексе оказались посторонние файлы: $($foreign -join ', '). Лок снят, захват отменён."
}

Invoke-Git -Arguments @('commit', '-m', "[$Task] chore(claim): acquire by $Owner") | Out-Null

$mainPush = Invoke-Git -Arguments @('push', 'origin', 'HEAD:refs/heads/main') -AllowFail
$attempt = 0
while ($mainPush.Code -ne 0 -and $attempt -lt 1) {
    $attempt++
    Write-Warn 'Push в main отвергнут (кто-то успел раньше) — rebase и повторная проверка конфликтов.'
    $rebase = Invoke-Git -Arguments @('pull', '--rebase', 'origin', 'main') -AllowFail
    if ($rebase.Code -ne 0) {
        Invoke-Git -Arguments @('rebase', '--abort') -AllowFail | Out-Null
        Invoke-Git -Arguments @('reset', '--hard', 'origin/main') -AllowFail | Out-Null
        Remove-ClaimRef -Ref $claimRef
        Fail "Не удалось совместить лиз с новым main. Лок $claimRef снят, захват отменён."
    }

    # Повторная проверка ПОСЛЕ rebase: именно здесь ловится чужой лиз задачи
    # и чужой захват тех же файлов.
    if (Test-Path -LiteralPath $claimFile) {
        $rival = Read-TaskFile -Path $claimFile
        if ("$(Get-TaskField -Task $rival -Key 'owner')" -ne $Owner -and -not (Test-LeaseExpired -Claim $rival)) {
            Invoke-Git -Arguments @('reset', '--hard', 'origin/main') -AllowFail | Out-Null
            Remove-ClaimRef -Ref $claimRef
            Fail "Задачу $Task одновременно взял $("$(Get-TaskField -Task $rival -Key 'owner')"). Лок снят, вы проиграли гонку — берите другую задачу."
        }
    }
    $lateConflicts = @(Get-PathConflicts -Paths $taskPaths -IgnoreTaskIds @($Task))
    if ($lateConflicts.Count -gt 0 -and -not $IgnorePathConflicts) {
        Invoke-Git -Arguments @('reset', '--hard', 'origin/main') -AllowFail | Out-Null
        Remove-ClaimRef -Ref $claimRef
        Fail ("После обновления main появились пересечения файлов:`n" +
            (Format-ConflictList -Conflicts $lateConflicts) + "`nЛок $claimRef снят.")
    }

    $mainPush = Invoke-Git -Arguments @('push', 'origin', 'HEAD:refs/heads/main') -AllowFail
}

if ($mainPush.Code -ne 0) {
    Invoke-Git -Arguments @('reset', '--hard', 'origin/main') -AllowFail | Out-Null
    Remove-ClaimRef -Ref $claimRef
    Fail "Не удалось записать лиз в main (нет прав на push?). Лок $claimRef снят.`n$($mainPush.Text)"
}
Write-Ok "Лиз tasks/claims/$Task.md опубликован в main."

# ---------------------------------------------------------------- шаг 9 ----
Write-Step "9. Создание ветки работы $branchName"
$switchBranch = Invoke-Git -Arguments @('switch', '-c', $branchName, '--track', 'origin/main') -AllowFail
if ($switchBranch.Code -ne 0) {
    Invoke-Git -Arguments @('switch', $branchName) | Out-Null
}
Invoke-Git -Arguments @('push', '-u', 'origin', $branchName) | Out-Null
Write-Ok "Ветка $branchName создана и запушена."

if ($startBranch -ne 'main' -and $startBranch -ne $branchName) {
    Write-Warn "До захвата вы были на ветке '$startBranch' — вернитесь к ней вручную, если нужно."
}

Write-Host ''
Write-Ok "Задача $Task принадлежит вам ($Owner) до $(ConvertTo-LeaseTime -Value $leaseUntil)."
Write-Host "Следующие шаги:" -ForegroundColor Cyan
Write-Host "  1. Работайте только в '$branchName' и только с файлами: $($taskPaths -join ', ')"
Write-Host "  2. Продление лока: pwsh -File scripts/agent/heartbeat.ps1 -Task $Task -Owner $Owner"
Write-Host "  3. Завершение:     pwsh -File scripts/agent/release.ps1   -Task $Task -Owner $Owner"
Write-Host "  4. PR -> squash merge -> ветка task/* удаляется автоматически."
exit 0
