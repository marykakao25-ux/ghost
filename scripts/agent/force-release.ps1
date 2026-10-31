#Requires -Version 5.1
<#
.SYNOPSIS
Аварийное снятие зависшего лока (claim/*, tasks/claims/*.md), без записи результата.

.DESCRIPTION
Нужен, когда агент упал и не выполнил release.ps1. Перед запуском убедитесь,
что работа не потеряется: git log origin/task/T-XXXX-*, или закройте задачу
через release.ps1 -Abort.

.EXAMPLE
pwsh -File scripts/agent/force-release.ps1 -Task T-0012 -Reason "агент упал, работы нет"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Task,
    [Parameter(Mandatory)][string]$Reason,
    [switch]$KeepTaskBranch
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AgentCommon.ps1')
Initialize-TaskSystem

Write-Warn "Принудительное снятие лока задачи $Task. Причина: $Reason"

if (-not (Test-CleanWorktree)) {
    Write-Err 'Рабочее дерево грязное — принудительное снятие отменено.'
    exit 1
}

Invoke-Git -Arguments @('switch', 'main') | Out-Null
Invoke-Git -Arguments @('pull', '--ff-only', 'origin', 'main') | Out-Null

$taskPath = $null
try {
    $taskPath = Find-Task -Id $Task
}
catch {
    # Задача уже закрыта (лежит в tasks/done/): остаётся только снять локи.
    Write-Warn "Задача $Task не найдена в tasks/ — снимаю только локи."
}

$claimFile = Join-Path $script:ClaimsDir "$Task.md"
$owner = '(none)'
if (Test-Path -LiteralPath $claimFile) {
    $owner = "$(Get-TaskField -Task (Read-TaskFile -Path $claimFile) -Key 'owner')"
    Invoke-Git -Arguments @('rm', '--quiet', '--', "tasks/claims/$Task.md") | Out-Null
}
if ($taskPath) {
    Set-TaskField -Path $taskPath -Key 'status' -Value 'todo'
    Set-TaskField -Path $taskPath -Key 'owner' -Value 'null'
    Set-TaskField -Path $taskPath -Key 'lease_until' -Value 'null'
    Set-TaskField -Path $taskPath -Key 'branch' -Value 'null'
    Add-TaskNote -Path $taskPath -Note "лок снят принудительно (был owner=$owner): $Reason"
    Invoke-Git -Arguments @('add', '--', "tasks/$(Split-Path -Leaf $taskPath)") | Out-Null
}
elseif ($owner -eq '(none)' -and -not (Test-Path -LiteralPath $claimFile)) {
    Write-Ok "Локов задачи $Task нет — снимать нечего."
}

$dirty = (Invoke-Git -Arguments @('status', '--porcelain', '--', 'tasks/')).Text
if ($dirty -ne '') {
    Invoke-Git -Arguments @('commit', '-m', "[$Task] chore(claim): force-release ($Reason)") | Out-Null
    $push = Invoke-Git -Arguments @('push', 'origin', 'HEAD:refs/heads/main') -AllowFail
    if ($push.Code -ne 0) {
        Invoke-Git -Arguments @('pull', '--rebase', 'origin', 'main') -AllowFail | Out-Null
        $push = Invoke-Git -Arguments @('push', 'origin', 'HEAD:refs/heads/main') -AllowFail
    }
    if ($push.Code -ne 0) {
        Write-Err "Не удалось обновить main; лок claim/$Task НЕ снят.`n$($push.Text)"
        exit 1
    }
    Write-Ok 'Лиз-файл снят.'
}

$claimRef = Get-ClaimBranch -Task $Task
if (Remove-RemoteRef -Ref $claimRef) { Write-Ok "$claimRef удалён." } else { Write-Warn "$claimRef уже отсутствовал." }

if (-not $KeepTaskBranch) {
    $taskBranchNames = @(Get-RemoteBranchNames -Pattern '*' | Where-Object {
            (Get-BranchPrefix -Name $_) -eq 'task' -and (Get-RemoteBranchSuffix -Name $_) -like "$Task-*"
        })
    foreach ($branch in $taskBranchNames) {
        if (Remove-RemoteRef -Ref $branch) { Write-Ok "Ветка $branch удалена (незамерженные коммиты остались в reflog сервера)." }
        else { Write-Warn "Не удалось удалить $branch." }
    }
}
exit 0
