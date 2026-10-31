#Requires -Version 5.1
<#
.SYNOPSIS
Продление лока задачи (heartbeat). Поддерживает лиз живым, пока идёт работа.

.DESCRIPTION
Обновляет lease_until в задачах tasks/claims/T-XXXX.md и tasks/T-XXXX-*.md
и пушит это в main. Запускать раз в 1–2 часа во время долгой работы.

.EXAMPLE
pwsh -File scripts/agent/heartbeat.ps1 -Task T-0012 -Owner cline
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Task,
    [Parameter(Mandatory)][string]$Owner,
    [int]$LeaseHours = 4
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AgentCommon.ps1')
Initialize-TaskSystem

function Fail {
    param([string]$Message)
    Write-Err $Message
    exit 1
}

if (-not (Test-CleanWorktree)) { Fail 'Рабочее дерево грязное — сначала закоммитьте изменения.' }
Invoke-Git -Arguments @('switch', 'main') | Out-Null
Invoke-Git -Arguments @('pull', '--ff-only', 'origin', 'main') | Out-Null

$taskPath = Find-Task -Id $Task
$claimFile = Join-Path $script:ClaimsDir "$Task.md"
if (-not (Test-Path -LiteralPath $claimFile)) { Fail "Лиз tasks/claims/$Task.md отсутствует — задача не взята." }

$claim = Read-TaskFile -Path $claimFile
$claimOwner = "$(Get-TaskField -Task $claim -Key 'owner')"
if ($claimOwner -ne $Owner) { Fail "Лиз принадлежит '$claimOwner', а не '$Owner'." }

$lease = Format-LeaseTime -Value ([datetime]::UtcNow.AddHours($LeaseHours))
Set-TaskField -Path $claimFile -Key 'lease_until' -Value $lease
Set-TaskField -Path $taskPath -Key 'lease_until' -Value $lease
Invoke-Git -Arguments @('add', '--', "tasks/claims/$Task.md", "tasks/$(Split-Path -Leaf $taskPath)") | Out-Null
Invoke-Git -Arguments @('commit', '-m', "[$Task] chore(claim): heartbeat $Owner") | Out-Null

$push = Invoke-Git -Arguments @('push', 'origin', 'HEAD:refs/heads/main') -AllowFail
if ($push.Code -ne 0) {
    Invoke-Git -Arguments @('pull', '--rebase', 'origin', 'main') -AllowFail | Out-Null
    $push = Invoke-Git -Arguments @('push', 'origin', 'HEAD:refs/heads/main') -AllowFail
}
if ($push.Code -ne 0) { Fail "Не удалось обновить лиз в main.`n$($push.Text)" }

Write-Ok "Лиз $Task продлён до $lease."
exit 0
