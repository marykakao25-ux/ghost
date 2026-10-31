<#
.SYNOPSIS
Общие функции для скриптов scripts/agent/*.ps1. Не запускается напрямую.

.DESCRIPTION
Здесь собрано всё, что должно вести себя одинаково во всех командах:
разбор front matter задач, работа с TTL, сравнение путей, вызовы git.

Скрипты рассчитаны на PowerShell 7+ (pwsh), но намеренно не используют
синтаксис, которого нет в Windows PowerShell 5.1.
#>

Set-StrictMode -Version Latest

# Прямые слэши, а не '..\..': CI (ubuntu-latest) не понимает обратный слэш как разделитель.
$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$script:TasksDir = Join-Path $script:RepoRoot 'tasks'
$script:ClaimsDir = Join-Path $script:TasksDir 'claims'
$script:DoneDir = Join-Path $script:TasksDir 'done'
$script:LeaseHours = 4

# ---------------------------------------------------------------- вывод ----

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[ok] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[x] $Message" -ForegroundColor Red
}

# ------------------------------------------------------------------ git ----

function Get-RepoRoot { return $script:RepoRoot }

function Invoke-Git {
    <#
    .SYNOPSIS
    Выполняет git в корне репозитория и возвращает результат.
    .PARAMETER AllowFail
    Не выбрасывать исключение при ненулевом коде возврата.
    #>
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$AllowFail
    )

    $output = & git -C $script:RepoRoot @Arguments 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0 -and -not $AllowFail) {
        throw "git $($Arguments -join ' ') завершился с кодом $code`n$($output -join "`n")"
    }
    return [pscustomobject]@{
        Code   = $code
        Output = @($output | ForEach-Object { "$_" })
        Text   = (@($output) -join "`n")
    }
}

function Get-CurrentBranch {
    $res = Invoke-Git -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')
    return $res.Text.Trim()
}

function Test-CleanWorktree {
    $res = Invoke-Git -Arguments @('status', '--porcelain')
    return [string]::IsNullOrWhiteSpace($res.Text)
}

function Get-RemoteBranchNames {
    <#
    .SYNOPSIS
    Возвращает имена удалённых веток, подходящих под glob-шаблон (например 'claim/T-0012*').
    Читает только сервер: локальный кэш мог устареть, а от этого зависит блокировка.
    #>
    param([Parameter(Mandatory)][string]$Pattern)

    $res = Invoke-Git -Arguments @('ls-remote', '--heads', 'origin', $Pattern) -AllowFail
    $names = foreach ($line in $res.Output) {
        if ($line -match 'refs/heads/(.+)$') { $Matches[1] }
    }
    return @($names)
}

function Get-BranchPrefix {
    # GitHub может создавать ветки с префиксами (user/, bot/). Наш лок — 'claim/' на любом уровне.
    param([Parameter(Mandatory)][string]$Name)
    if ($Name -match '(^|/)claim/') { return 'claim' }
    if ($Name -match '(^|/)task/') { return 'task' }
    return ''
}

function Get-RemoteBranchSuffix {
    <#
    .SYNOPSIS
    Отбрасывает префиксы и возвращает «хвост» имени ветки.
    'user/claim/T-0002' -> 'T-0002'; 'task/T-0002-menu' -> 'T-0002-menu'
    #>
    param([Parameter(Mandatory)][string]$Name)
    if ($Name -match '(^|/)(claim|task)/(.+)$') { return $Matches[3] }
    return $Name
}

function Test-RemoteBranch {
    <#
    .SYNOPSIS
    Есть ли на origin ветка с таким «хвостом» и указанным префиксом (claim/task).
    Префикс не фиксирован: ветка, созданная через веб-интерфейс, тоже блокирует задачу.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Prefix
    )
    foreach ($remote in @(Get-RemoteBranchNames -Pattern '*')) {
        if ((Get-BranchPrefix -Name $remote) -eq $Prefix -and (Get-RemoteBranchSuffix -Name $remote) -eq $Name) {
            return $true
        }
    }
    return $false
}

function Get-ClaimBranch {
    <#
    .SYNOPSIS
    Настоящее имя лок-ветки задачи: то, что уже есть на origin, иначе claim/<Task>.
    #>
    param([Parameter(Mandatory)][string]$Task)
    foreach ($remote in @(Get-RemoteBranchNames -Pattern '*')) {
        if ((Get-BranchPrefix -Name $remote) -eq 'claim' -and (Get-RemoteBranchSuffix -Name $remote) -eq $Task) {
            return $remote
        }
    }
    return "claim/$Task"
}

function Remove-RemoteRef {
    <#
    .SYNOPSIS
    Удаляет ветку на origin по точному имени. Возвращает $true при успехе.
    #>
    param([Parameter(Mandatory)][string]$Ref)
    $res = Invoke-Git -Arguments @('push', 'origin', '--delete', $Ref) -AllowFail
    return ($res.Code -eq 0)
}

function Set-GitIdentityIfMissing {
    # Для агентов без настроенного git: коммиты лока должны быть подписаны хоть как-то.
    $name = Invoke-Git -Arguments @('config', 'user.name') -AllowFail
    if ($name.Code -ne 0 -or [string]::IsNullOrWhiteSpace($name.Text)) {
        Invoke-Git -Arguments @('config', 'user.name', 'ghost-agent') -AllowFail | Out-Null
    }
    $email = Invoke-Git -Arguments @('config', 'user.email') -AllowFail
    if ($email.Code -ne 0 -or [string]::IsNullOrWhiteSpace($email.Text)) {
        Invoke-Git -Arguments @('config', 'user.email', 'agent@localhost') -AllowFail | Out-Null
    }
}

# ------------------------------------------------------------ front matter ----

function ConvertFrom-FrontMatterScalar {
    # 'value', "value" -> value | [a, b] -> @('a','b') | null/~/пусто -> $null | остальное как есть
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Raw)

    $value = $Raw.Trim()
    if ($value -eq '' -or $value -eq 'null' -or $value -eq '~') { return $null }

    if ($value -match '^\[(.*)\]$') {
        $inner = $Matches[1].Trim()
        if ($inner -eq '') { return @() }
        return @(
            $inner -split ',' |
                ForEach-Object { $_.Trim().Trim("'").Trim('"') } |
                Where-Object { $_ -ne '' }
        )
    }

    return $value.Trim("'").Trim('"')
}

function Read-TaskFile {
    <#
    .SYNOPSIS
    Читает задачу и разбирает YAML-подобный front matter без внешних зависимостей.
    Поддерживаются скаляры, inline-списки [a, b] и блочные списки через перенос строки.
    #>
    param([Parameter(Mandatory)][string]$Path)

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $raw = $raw -replace "`r`n", "`n"

    if ($raw -notmatch '(?s)^\s*---\n(.*?)\n---\n?(.*)$') {
        throw "В файле '$Path' нет front matter (--- ... ---)."
    }

    $front = $Matches[1]
    $body = $Matches[2]
    $data = [ordered]@{}
    $listKey = $null

    foreach ($line in ($front -split "`n")) {
        if ($line.Trim() -eq '' -or $line.TrimStart().StartsWith('#')) { continue }

        if ($line -match '^\s*-\s+(.*)$' -and $listKey) {
            $data[$listKey] = @($data[$listKey]) + (ConvertFrom-FrontMatterScalar -Raw $Matches[1])
            continue
        }

        if ($line -match '^([A-Za-z_][A-Za-z0-9_-]*):\s*(.*)$') {
            $key = $Matches[1]
            $rest = $Matches[2]
            if ($rest.Trim() -eq '') {
                $data[$key] = @()
                $listKey = $key
            }
            else {
                $data[$key] = ConvertFrom-FrontMatterScalar -Raw $rest
                $listKey = $null
            }
        }
    }

    return [pscustomobject]@{
        Path = $Path
        Name = [System.IO.Path]::GetFileName($Path)
        Data = $data
        Body = $body
    }
}

function Get-TaskField {
    param(
        [Parameter(Mandatory)]$Task,
        [Parameter(Mandatory)][string]$Key
    )
    if ($Task.Data.Contains($Key)) { return $Task.Data[$Key] }
    return $null
}

function Set-TaskField {
    <#
    .SYNOPSIS
    Меняет одно скалярное поле front matter, не трогая остальной файл.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $pattern = "(?m)^" + [regex]::Escape($Key) + ":[ \t]*.*$"
    # Строка для вставки собирается заранее: внутри scriptblock `":` распознаётся
    # как часть имени переменной и ломает регулярку (проверено тестом).
    $line = $Key + ': ' + $Value
    if ([regex]::IsMatch($raw, $pattern)) {
        $raw = [regex]::Replace($raw, $pattern, $line)
    }
    else {
        $head = '---' + "`n" + $line
        $raw = [regex]::Replace($raw, '(?m)^---$', $head, 1)
    }
    Set-Content -LiteralPath $Path -Value $raw -Encoding UTF8 -NoNewline
}

function Add-TaskNote {
    <#
    .SYNOPSIS
    Дописывает строку в конец файла задачи — используется для истории takeover и релиза.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Note
    )
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $line = "- $stamp — $Note"
    Add-Content -LiteralPath $Path -Value $line -Encoding UTF8
}

function Get-AllTasks {
    <#
    .SYNOPSIS
    Все задачи проекта: активные в tasks/ и завершённые в tasks/done/.
    #>
    $files = @()
    foreach ($dir in @($script:TasksDir, $script:DoneDir)) {
        if (Test-Path -LiteralPath $dir) {
            $files += Get-ChildItem -LiteralPath $dir -Filter 'T-*.md' -File -ErrorAction SilentlyContinue
        }
    }

    $tasks = foreach ($file in ($files | Sort-Object FullName)) {
        try {
            $task = Read-TaskFile -Path $file.FullName
            $task.Data['_dir'] = Split-Path -Leaf (Split-Path -Parent $file.FullName)
            $task
        }
        catch {
            Write-Warn "Задача $($file.Name) не разобрана: $($_.Exception.Message)"
        }
    }
    return @($tasks)
}

function Find-Task {
    <#
    .SYNOPSIS
    Находит файл задачи по id (T-0012 -> tasks/T-0012-*.md).
    #>
    param([Parameter(Mandatory)][string]$Id)

    $Id = $Id.Trim().ToUpperInvariant()
    if ($Id -notmatch '^T-\d{4}$') {
        throw "Некорректный id задачи '$Id'. Ожидается формат T-0001."
    }
    $found = @(Get-ChildItem -LiteralPath $script:TasksDir -Filter "$Id-*.md" -File -ErrorAction SilentlyContinue)
    if ($found.Count -eq 0) { throw "Задача $Id не найдена в tasks/." }
    if ($found.Count -gt 1) { throw "Найдено несколько файлов для ${Id}: $(($found | ForEach-Object { $_.Name }) -join ', ')." }
    return $found[0].FullName
}

# ------------------------------------------------------------- ЛИЗЫ / TTL ----

function Get-ActiveClaims {
    <#
    .SYNOPSIS
    Активные лизы из tasks/claims/ (разобранные как задачи: id/owner/paths/lease_until).
    #>
    if (-not (Test-Path -LiteralPath $script:ClaimsDir)) { return @() }
    $claims = foreach ($file in (Get-ChildItem -LiteralPath $script:ClaimsDir -Filter 'T-*.md' -File)) {
        try { Read-TaskFile -Path $file.FullName } catch { Write-Warn "Лиз $($file.Name) не разобран." }
    }
    return @($claims)
}

function ConvertTo-LeaseTime {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -eq 'null') { return $null }

    $styles = [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal
    $parsed = [datetime]::MinValue
    $ok = [datetime]::TryParse(
        $Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        $styles,
        [ref]$parsed
    )
    if (-not $ok) { return $null }
    return $parsed
}

function Format-LeaseTime {
    param([Parameter(Mandatory)][datetime]$Value)
    return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

function Test-LeaseExpired {
    param([AllowNull()]$Claim)
    if ($null -eq $Claim) { return $true }
    $until = ConvertTo-LeaseTime -Value (Get-TaskField -Task $Claim -Key 'lease_until')
    if ($null -eq $until) { return $true }
    return $until -le [datetime]::UtcNow
}

function Get-LeaseRemaining {
    param([AllowNull()]$Claim)
    if ($null -eq $Claim) { return '' }
    $until = ConvertTo-LeaseTime -Value (Get-TaskField -Task $Claim -Key 'lease_until')
    if ($null -eq $until) { return 'no-ttl' }
    $delta = $until - [datetime]::UtcNow
    if ($delta.Ticks -le 0) { return 'EXPIRED' }
    return ('{0}h{1:d2}m' -f [int][math]::Floor($delta.TotalHours), $delta.Minutes)
}

# ------------------------------------------------------------------ paths ----

function Normalize-RepoPath {
    param([AllowEmptyString()][AllowNull()][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    $p = $Path.Trim().Replace('\', '/')
    $p = $p -replace '^\./', '' -replace '/+$', ''
    # Нижний регистр: на Windows/в git-индексе регистр файлов не различается,
    # а именно там вероятность потерять конфликт выше всего.
    return $p.ToLowerInvariant()
}

function Test-PathOverlap {
    <#
    .SYNOPSIS
    Пересекаются ли два пути: равенство либо префикс по границе каталога.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$A,
        [Parameter(Mandatory)][AllowEmptyString()][string]$B
    )

    $a = Normalize-RepoPath -Path $A
    $b = Normalize-RepoPath -Path $B
    if ($a -eq '' -or $b -eq '') { return $false }
    if ($a -eq $b) { return $true }
    return ($a.StartsWith($b + '/') -or $b.StartsWith($a + '/'))
}

function ConvertTo-StringArray {
    <#
    .SYNOPSIS
    Приводит значение front matter к массиву строк.
    Одиночная строка (поле с одним элементом без "- ") тоже становится массивом из одного элемента.
    Унарная запятая перед return не даёт PowerShell развернуть одноэлементный массив в скаляр.
    #>
    param([AllowNull()]$Value)

    if ($null -eq $Value) { return , @() }
    if ($Value -is [string]) {
        if ($Value.Trim() -eq '') { return , @() }
        return , @($Value)
    }
    return , @($Value | ForEach-Object { "$_" })
}

function Get-PathConflicts {
    <#
    .SYNOPSIS
    Конфликты набора путей с активными лизами (кроме перечисленных id).
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Paths,
        [AllowEmptyCollection()][string[]]$IgnoreTaskIds = @(),
        [AllowNull()]$Claims = $null
    )

    if ($null -eq $Claims) { $Claims = Get-ActiveClaims }

    $conflicts = New-Object System.Collections.Generic.List[object]
    foreach ($claim in $Claims) {
        $claimId = "$(Get-TaskField -Task $claim -Key 'id')"
        if ($claimId -eq '') { $claimId = $claim.Name }
        if ($IgnoreTaskIds -contains $claimId) { continue }

        $claimPaths = ConvertTo-StringArray -Value (Get-TaskField -Task $claim -Key 'paths')
        foreach ($path in $Paths) {
            foreach ($claimPath in $claimPaths) {
                if (Test-PathOverlap -A "$path" -B "$claimPath") {
                    $hit = [pscustomobject]@{}
                    $hit | Add-Member -NotePropertyName TaskId -NotePropertyValue $claimId
                    $hit | Add-Member -NotePropertyName Owner -NotePropertyValue "$(Get-TaskField -Task $claim -Key 'owner')"
                    $hit | Add-Member -NotePropertyName Path -NotePropertyValue "$path"
                    $hit | Add-Member -NotePropertyName Claimed -NotePropertyValue "$claimPath"
                    [void]$conflicts.Add($hit)
                }
            }
        }
    }
    if ($conflicts.Count -eq 0) { return @() }
    return $conflicts.ToArray()
}

function Format-ConflictList {
    param([AllowEmptyCollection()]$Conflicts)
    return (@($Conflicts | ForEach-Object {
                "  - $($_.TaskId) ($($_.Owner)) держит '$($_.Claimed)' -> конфликт с '$($_.Path)'"
            }) -join "`n")
}

# -------------------------------------------------------------- прочее ----

function Initialize-TaskSystem {
    <#
    .SYNOPSIS
    Создаёт пустые папки tasks/claims и tasks/done.

    .DESCRIPTION
    Git не хранит пустые каталоги, а без них Get-ChildItem и проверки падают на «первом запуске».
    Вызывайте в начале каждого скрипта: это дёшево и делает систему устойчивой к чистому клону.
    #>
    foreach ($dir in @($script:TasksDir, $script:ClaimsDir, $script:DoneDir)) {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
}

function Read-RepoText {
    # Явная UTF-8: в Windows PowerShell 5.1 Get-Content по умолчанию читает ANSI.
    param([Parameter(Mandatory)][string]$RelativePath)
    $path = Join-Path $script:RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path)) { return '' }
    return (Get-Content -LiteralPath $path -Raw -Encoding UTF8)
}
