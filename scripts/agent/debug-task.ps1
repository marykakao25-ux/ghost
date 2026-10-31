#Requires -Version 5.1
<#
.SYNOPSIS
Диагностика механизма задач: разбор T-0002, пересечения путей, типы значений.
Запуск: pwsh -File scripts/agent/debug-task.ps1 -Task T-0002
#>
param([string]$Task = 'T-0002')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AgentCommon.ps1')
Initialize-TaskSystem

Write-Host "--- Normalize ---"
Write-Host ("result: '" + (Normalize-RepoPath -Path 'project.godot') + "'")

Write-Host "--- Test-PathOverlap ---"
try {
    $r = Test-PathOverlap -A 'project.godot' -B 'project.godot'
    Write-Host "overlap: $r"
}
catch {
    Write-Host "OVERLAP ERROR: $($_.Exception.GetType().FullName) :: $($_.Exception.Message)"
}

Write-Host "--- Get-PathConflicts ---"
try {
    $c = @(Get-PathConflicts -Paths @('project.godot') -IgnoreTaskIds @('T-0002'))
    Write-Host "conflicts: $($c.Count)"
}
catch {
    Write-Host "CONFLICTS ERROR: $($_.Exception.GetType().FullName) :: $($_.Exception.Message)"
    Write-Host "STACK: $($_.ScriptStackTrace)"
}

try {
    $path = Find-Task -Id $Task
    Write-Host "file: $path"
    $t = Read-TaskFile -Path $path
    $paths = ConvertTo-StringArray -Value (Get-TaskField -Task $t -Key 'paths')
    Write-Host "paths count = $($paths.Count)"
}
catch {
    Write-Host "FIND ERROR: $($_.Exception.GetType().FullName)"
    Write-Host "MESSAGE: $($_.Exception.Message)"
    Write-Host "STACK: $($_.ScriptStackTrace)"
}
