#Requires -Version 5.1
<#
.SYNOPSIS
Закрытие задачи: перенос в tasks/done/, снятие лиза и лок-ветки.

.DESCRIPTION
Порядок критичен: сначала работа коммитится и пушится в task/*, и только
потом снимается лок claim/*. Снять лок раньше — значит дать другому агенту
взять задачу, пока работа ещё не сохранена на сервере.

.EXAMPLE
pwsh -File scripts/agent/release.ps1 -Task T-0012 -Owner cline
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Task,
    [Parameter(Mandatory)][string]$Owner,
    [switch]$Abort   # закрыть задачу как «отменена»: изменения не вливаются
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AgentCommon.ps1')
Initialize-TaskSystem

function Fail {
    param([string]$Message)
    Write-Err $Message
    exit 1
}

Write-Step "1. Чтение задачи $Task"
$taskPath = Find-Task -Id $Task
$taskData = Read-TaskFile -Path $taskPath
$claimFile = Join-Path $script:ClaimsDir "$Task.md"

if (-not (Test-Path -LiteralPath $claimFile)) {
    Fail "Нет лиз-файла tasks/claims/$Task.md — задачу никто не держал (или лиз уже снят)."
}
$claim = Read-TaskFile -Path $claimFile
$claimOwner = "$(Get-TaskField -Task $claim -Key 'owner')"
$branchName = "$(Get-TaskField -Task $claim -Key 'branch')"
$claimedLock = "$(Get-TaskField -Task $claim -Key 'lock_ref')"
$claimRef = if ($claimedLock -ne '') { $claimedLock } else { Get-ClaimBranch -Task $Task }

if ($claimOwner -ne $Owner) {
    Fail "Лиз принадлежит '$claimOwner', а вы '$Owner'. Задачу закрывает только владелец (или force-release.ps1)."
}

Write-Step "2. Проверка, что работа сохранена в ветке $branchName"
$localBranch = Get-CurrentBranch
if (-not (Test-CleanWorktree)) {
    Fail "Рабочее дерево грязное: закоммитьте изменения перед закрытием задачи."
}

if (-not $Abort) {
    $remoteTaskBranch = Test-RemoteBranch -Name (Get-RemoteBranchSuffix -Name $branchName) -Prefix 'task'
    if (-not $remoteTaskBranch) {
        Fail "Ветка работы $branchName не существует на origin. Запушьте работу: git push -u origin $branchName"
    }
    $ahead = Invoke-Git -Arguments @('rev-list', '--count', "origin/$branchName..HEAD") -AllowFail
    if ($localBranch -eq $branchName -and $ahead.Code -eq 0 -and [int]$ahead.Text.Trim() -gt 0) {
        Fail "В $branchName есть незапушенные коммиты ($($ahead.Text.Trim())). Сначала git push."
    }
}

Write-Step '3. Обновление main и перенос задачи в tasks/done/'
$returnBranch = if ($localBranch -match '^task/') { $localBranch } else { 'main' }
Invoke-Git -Arguments @('switch', 'main') | Out-Null
Invoke-Git -Arguments @('pull', '--ff-only', 'origin', 'main') | Out-Null

$donePath = Join-Path $script:DoneDir (Split-Path -Leaf $taskPath)
if (-not (Test-Path -LiteralPath $script:DoneDir)) {
    New-Item -ItemType Directory -Path $script:DoneDir -Force | Out-Null
}

Set-TaskField -Path $taskPath -Key 'status' -Value $(if ($Abort) { 'blocked' } else { 'done' })
$note = if ($Abort) {
    "задача снята владельцем $Owner (работа не вливается), ветка $branchName"
}
else {
    "работа завершена владельцем $Owner, ветка $branchName, ожидает PR"
}
Add-TaskNote -Path $taskPath -Note $note

Invoke-Git -Arguments @('add', '--', "tasks/$(Split-Path -Leaf $taskPath)") | Out-Null
Invoke-Git -Arguments @('mv', '-f', "tasks/$(Split-Path -Leaf $taskPath)", "tasks/done/$(Split-Path -Leaf $taskPath)") | Out-Null
Invoke-Git -Arguments @('rm', '--quiet', '--ignore-unmatch', '--', "tasks/claims/$Task.md") | Out-Null

Write-Step '4. Коммит и push в main'
Invoke-Git -Arguments @('commit', '-m', "[$Task] chore: release ($Owner)") | Out-Null
$push = Invoke-Git -Arguments @('push', 'origin', 'HEAD:refs/heads/main') -AllowFail
if ($push.Code -ne 0) {
    Invoke-Git -Arguments @('pull', '--rebase', 'origin', 'main') -AllowFail | Out-Null
    $push = Invoke-Git -Arguments @('push', 'origin', 'HEAD:refs/heads/main') -AllowFail
}
if ($push.Code -ne 0) {
    Fail "Не удалось записать релиз в main. Лок НЕ снят — повторите release.ps1.`n$($push.Text)"
}
Write-Ok "Лиз снят, задача перенесена в tasks/done/."

Write-Step "5. Снятие лок-ветки $claimRef"
if (Remove-RemoteRef -Ref $claimRef) { Write-Ok "$claimRef удалён." }
else { Write-Warn "$claimRef не удалён (уже нет или нет прав)." }

if ($Abort) {
    Invoke-Git -Arguments @('switch', 'main') | Out-Null
    Write-Host ''
    Write-Ok "Задача $Task закрыта как отменённая. Ветка $branchName осталась в origin — удалите вручную при необходимости."
    exit 0
}

Invoke-Git -Arguments @('switch', $returnBranch) | Out-Null
Write-Host ''
Write-Ok "Готово. Осталось открыть PR и влить squash-merge:"
Write-Host "  ветка:  $branchName"
Write-Host "  задача: $Task"
Write-Host '  В названии PR обязательно укажите [T-XXXX]: это проверяет workflow agent-guard.yml.'
exit 0
