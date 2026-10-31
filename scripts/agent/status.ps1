#Requires -Version 5.1
<#
.SYNOPSIS
Таблица состояния задач: кто что держит, сколько живёт лок, где расхождения слоёв A и B.

.DESCRIPTION
Читает локальные tasks/ и задачи удалённые claim/*, task/* (git ls-remote).
Это первое, что запускает агент, чтобы понять, за что можно браться.
Код возврата 1 — если найдены расхождения, требующие внимания.

.EXAMPLE
pwsh -File scripts/agent/status.ps1
#>
[CmdletBinding()]
param(
    [switch]$NoRemote
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AgentCommon.ps1')

$rows = New-Object System.Collections.Generic.List[object]
$problems = New-Object System.Collections.Generic.List[string]

$tasks = Get-AllTasks
$claims = Get-ActiveClaims

$claimsById = @{}
foreach ($claim in $claims) {
    $id = "$(Get-TaskField -Task $claim -Key 'id')"
    if ($id -ne '') { $claimsById[$id] = $claim }
}

$remoteClaims = @()
$remoteTaskBranches = @()
if (-not $NoRemote) {
    Invoke-Git -Arguments @('fetch', '--prune', 'origin') -AllowFail | Out-Null
    $remoteClaims = @(Get-RemoteBranchNames -Pattern 'claim/*' | ForEach-Object { $_ -replace '^claim/', '' })
    $remoteTaskBranches = @(Get-RemoteBranchNames -Pattern 'task/*')
}

foreach ($task in $tasks) {
    $id = "$(Get-TaskField -Task $task -Key 'id')"
    if ($id -eq '') { $id = ($task.Name -split '-')[0..1] -join '-' }
    $dir = "$(Get-TaskField -Task $task -Key '_dir')"
    $status = "$(Get-TaskField -Task $task -Key 'status')"
    $owner = "$(Get-TaskField -Task $task -Key 'owner')"
    $branch = "$(Get-TaskField -Task $task -Key 'branch')"

    $claim = if ($claimsById.ContainsKey($id)) { $claimsById[$id] } else { $null }
    $ttl = if ($claim) { Get-LeaseRemaining -Claim $claim } else { '' }
    $lockRef = if ($remoteClaims -contains $id) { 'yes' } elseif ($NoRemote) { '?' } else { 'MISSING' }
    $workBranch = @($remoteTaskBranches | Where-Object { $_ -like "task/$id-*" })
    $work = if ($workBranch.Count -gt 0) { $workBranch[0] -replace "^task/$id-", '' } else { '' }

    $overlap = ''
    if ($claim) {
        $ownPaths = @(Get-TaskField -Task $claim -Key 'claimed_paths')
        $conflicts = @(Get-PathConflicts -Paths $ownPaths -IgnoreTaskIds @($id) -Claims $claims)
        if ($conflicts.Count -gt 0) {
            $overlap = '⚠ ' + (($conflicts | ForEach-Object { $_.TaskId } | Select-Object -Unique) -join ',')
        }
    }

    if ($claim -and -not $NoRemote -and $lockRef -eq 'MISSING') {
        $problems.Add("$id : лиз в tasks/claims есть, а claim/$id в origin отсутствует — лок потерян.")
    }
    if ($ttl -eq 'EXPIRED') { $problems.Add("$id : лиз просрочен (owner=$owner). Можно -Takeover.") }
    if (-not $claim -and $lockRef -eq 'yes') {
        $problems.Add("$id : есть claim/$id, но нет файла tasks/claims/$id.md — расхождение слоёв A и B.")
    }
    if (-not $claim -and $work -ne '') {
        $problems.Add("$id : ветка работы task/$id-* жива, а лиза нет — работа брошена.")
    }
    if ($overlap -ne '') { $problems.Add("$id : пересечение файлов с $overlap") }

    $rows.Add([pscustomobject]@{
            ID       = $id
            STATUS   = $status
            DIR      = $dir
            OWNER    = if ($owner -eq '' -or $owner -eq 'null') { '-' } else { $owner }
            TTL      = if ($ttl -eq '') { '-' } else { $ttl }
            LOCKREF  = if ($NoRemote) { '?' } else { $lockRef }
            BRANCH   = if ($work -eq '') { '-' } else { $work }
            OVERLAP  = if ($overlap -eq '') { '-' } else { $overlap }
        })
}

if ($rows.Count -eq 0) {
    Write-Warn 'Задач не найдено: tasks/ пуст.'
    exit 0
}

$rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host

$free = @($rows | Where-Object { $_.STATUS -eq 'todo' -and $_.OWNER -eq '-' })
Write-Host ("Свободных задач: {0}" -f $free.Count) -ForegroundColor Green
if ($free.Count -gt 0) {
    Write-Host ("  " + (($free | ForEach-Object { $_.ID }) -join ', '))
}

if ($problems.Count -gt 0) {
    Write-Host ''
    Write-Warn 'Требует внимания:'
    foreach ($p in $problems) { Write-Host "  - $p" -ForegroundColor Yellow }
    exit 1
}
Write-Ok 'Расхождений между tasks/ и origin нет.'
exit 0
