#Requires -Version 5.1
<#
.SYNOPSIS
Проверки проекта перед PR: валидность задач, гигиена git, импорт Godot.

.DESCRIPTION
Запускается агентом перед сдачей работы и в CI. Не требует установленного
Godot: если бинарь не найден, проверка импорта пропускается с предупреждением.
Код возврата 1 при любой ошибке.

.PARAMETER SelfTest
Проверить только сам механизм задач (разбор front matter, пересечение путей).
#>
[CmdletBinding()]
param(
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AgentCommon.ps1')
Initialize-TaskSystem

$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-Error { param([string]$m) $script:errors.Add($m) }
function Add-Warning { param([string]$m) $script:warnings.Add($m) }

# ------------------------------------------------------------ самотест ----
if ($SelfTest) {
    Write-Step 'Самотест механизма задач'
    $fail = 0

    $cases = @(
        @{ A = 'scripts/MovementCat.gd'; B = 'scripts/MovementCat.gd'; Expect = $true }
        @{ A = 'assets/sprites/cat'; B = 'assets/sprites/cat/cat_idle1.png'; Expect = $true }
        @{ A = 'assets/sprites/cat'; B = 'assets/sprites/cat2/x.png'; Expect = $false }
        @{ A = 'scripts/MovementCat.gd'; B = 'scripts/MovementDog.gd'; Expect = $false }
        @{ A = 'scenes/Level_Cat_Cemetry.tscn'; B = 'scenes'; Expect = $true }
        @{ A = 'PROJECT.GODOT'; B = 'project.godot'; Expect = $true }
        @{ A = 'project.godot'; B = 'assets/x.png'; Expect = $false }
    )
    foreach ($case in $cases) {
        $got = Test-PathOverlap -A $case.A -B $case.B
        if ($got -eq $case.Expect) { Write-Ok "overlap '$($case.A)' vs '$($case.B)' = $got" }
        else { Add-Error "overlap '$($case.A)' vs '$($case.B)': ожидалось $($case.Expect), получено $got"; $fail++ }
    }

    # Одиночная строка вместо массива — самая частая причина ложных падений.
    $single = @(ConvertTo-StringArray -Value 'project.godot')
    if ($single.Count -eq 1 -and $single[0] -eq 'project.godot') { Write-Ok 'одиночная строка приведена к массиву' }
    else { Add-Error "ConvertTo-StringArray вернул $($single.Count) элементов"; $fail++ }
    $empty = @(ConvertTo-StringArray -Value $null)
    if ($empty.Count -eq 0) { Write-Ok 'null приведён к пустому массиву' }
    else { Add-Error 'ConvertTo-StringArray для $null вернул непустой массив'; $fail++ }

    $sample = Join-Path ([System.IO.Path]::GetTempPath()) "ghost-task-$([guid]::NewGuid().ToString('N')).md"
    @(
        '---'
        'id: T-0999'
        'title: Проверка разбора'
        'status: todo'
        'owner: null'
        'paths:'
        '  - scripts/A.gd'
        '  - "scenes/B.tscn"'
        'depends_on: [T-0001, T-0002]'
        '---'
        ''
        '## Контекст'
    ) | Set-Content -LiteralPath $sample -Encoding UTF8
    $parsed = Read-TaskFile -Path $sample
    $paths = @(ConvertTo-StringArray -Value (Get-TaskField -Task $parsed -Key 'paths'))
    if ($paths.Count -eq 2 -and $paths[1] -eq 'scenes/B.tscn') { Write-Ok "блочный список paths разобран: $($paths -join ', ')" }
    else { Add-Error "блочный список paths разобран неверно: $($paths -join ', ')"; $fail++ }
    $deps = @(ConvertTo-StringArray -Value (Get-TaskField -Task $parsed -Key 'depends_on'))
    if ($deps.Count -eq 2) { Write-Ok "inline-список depends_on разобран: $($deps -join ', ')" }
    else { Add-Error "inline-список depends_on разобран неверно: $($deps -join ', ')"; $fail++ }
    if ($null -eq (Get-TaskField -Task $parsed -Key 'owner')) { Write-Ok 'null разобран как $null' }
    else { Add-Error "'null' не превратился в `$null"; $fail++ }
    Remove-Item -LiteralPath $sample -Force

    Write-Host ''
    if ($fail -gt 0) { Write-Err "Самотест провален ($fail)."; exit 1 }
    Write-Ok 'Самотест пройден.'
    exit 0
}

# ------------------------------------------------------------- задачи ----
Write-Step '1. Проверка задач в tasks/'
$tasks = @(Get-AllTasks)
if ($tasks.Count -eq 0) { Add-Warning 'В tasks/ нет задач.' }

$ids = @{}
foreach ($task in $tasks) {
    $file = $task.Name
    $id = "$(Get-TaskField -Task $task -Key 'id')"
    if ($id -notmatch '^T-\d{4}$') { Add-Error "${file}: поле id отсутствует или некорректно ('$id')."; continue }
    if ($file -notmatch "^$id-") { Add-Error "${file}: имя файла не начинается с $id-." }
    if ($ids.ContainsKey($id)) { Add-Error "${file}: дубликат id $id." } else { $ids[$id] = $task }

    $status = "$(Get-TaskField -Task $task -Key 'status')"
    if ('todo', 'claimed', 'in-progress', 'review', 'done', 'blocked' -notcontains $status) {
        Add-Error "${file}: неизвестный status '$status'."
    }
    $paths = @(ConvertTo-StringArray -Value (Get-TaskField -Task $task -Key 'paths'))
    if ($paths.Count -eq 0 -and $status -ne 'done') { Add-Error "${file}: пустое поле paths." }
    foreach ($p in $paths) {
        if ($p -match '^/' -or $p -match '^[A-Za-z]:') { Add-Error "${file}: путь '$p' должен быть относительным от корня репозитория." }
    }

    $dir = "$(Get-TaskField -Task $task -Key '_dir')"
    if ($status -eq 'done' -and $dir -ne 'done') { Add-Error "${file}: status=done, но файл не в tasks/done/." }
    if ($status -ne 'done' -and $dir -eq 'done') { Add-Error "${file}: файл в tasks/done/, но status=$status." }
}
Write-Ok "Задач: $($tasks.Count)"

# --------------------------------------------------------------- лизы ----
Write-Step '2. Проверка лизов tasks/claims/'
$claims = @(Get-ActiveClaims)
foreach ($claim in $claims) {
    $id = "$(Get-TaskField -Task $claim -Key 'id')"
    if (-not $ids.ContainsKey($id)) { Add-Error "claims/$($claim.Name): нет соответствующей задачи $id." }
    if ("$(Get-TaskField -Task $claim -Key 'owner')" -eq 'null') { Add-Error "claims/$($claim.Name): пустой owner." }
    if (Test-LeaseExpired -Claim $claim) { Add-Warning "claims/$($claim.Name): лок просрочен, задачу можно перехватить." }
}
Write-Ok "Лизов: $($claims.Count)"

for ($i = 0; $i -lt $claims.Count; $i++) {
    for ($j = $i + 1; $j -lt $claims.Count; $j++) {
        $a = $claims[$i]; $b = $claims[$j]
        foreach ($pa in (ConvertTo-StringArray -Value (Get-TaskField -Task $a -Key 'claimed_paths'))) {
            foreach ($pb in (ConvertTo-StringArray -Value (Get-TaskField -Task $b -Key 'claimed_paths'))) {
                if (Test-PathOverlap -A $pa -B $pb) {
                    Add-Error "Лизы $(Get-TaskField -Task $a -Key 'id') и $(Get-TaskField -Task $b -Key 'id') захватили один файл: '$pa' / '$pb'."
                }
            }
        }
    }
}

# ---------------------------------------------------------- гигиена git ----
Write-Step '3. Гигиена репозитория'
$tracked = @((Invoke-Git -Arguments @('ls-files')).Output)
$forbidden = @(
    @{ Pattern = '^\.godot/'; What = 'кэш Godot .godot/' }
    @{ Pattern = '^build/|^builds/|^export/'; What = 'каталог сборки' }
    @{ Pattern = '\.(exe|pck|apk|aab|dmg)$'; What = 'артефакт сборки' }
    @{ Pattern = '\.(keystore|jks)$'; What = 'ключ подписи' }
    @{ Pattern = '^\.vs/|\.user$|\.suo$'; What = 'файл IDE' }
)
foreach ($rule in $forbidden) {
    $hits = @($tracked | Where-Object { $_ -match $rule.Pattern })
    foreach ($hit in $hits) { Add-Error "В индексе лишний файл ($($rule.What)): $hit" }
}
Write-Ok "Файлов в индексе: $($tracked.Count)"

# .import и .uid — производные файлы Godot: их нельзя править руками,
# но и удалять из индекса нельзя (иначе ломаются uid-ссылки в сценах).
$missingImport = @($tracked | Where-Object { $_ -match '^assets/.*\.(png|mp3|ogg|wav|ttf)$' } | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $script:RepoRoot "$_.import"))
    })
foreach ($m in $missingImport) { Add-Warning "Нет .import для ассета: $m (переимпортируйте проект в Godot)." }

# ------------------------------------------------------- Godot, если есть ----
Write-Step '4. Проверка проекта Godot'
$godot = $null
foreach ($candidate in @('godot', 'Godot', 'godot4', 'Godot_v4.7-stable_win64.exe')) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) { $godot = $cmd.Source; break }
}
if (-not $godot) {
    Add-Warning 'Godot не найден в PATH — проверка импорта пропущена. Установите Godot 4.7 и добавьте в PATH.'
}
else {
    Write-Ok "Godot: $godot"
    $headless = & $godot --headless --path $script:RepoRoot --quit 2>&1
    $exit = $LASTEXITCODE
    $text = ($headless | ForEach-Object { "$_" }) -join "`n"
    if ($exit -ne 0) { Add-Error "Godot завершился с кодом ${exit}:`n$text" }
    $scriptErrors = @($headless | Where-Object { "$_" -match 'SCRIPT ERROR|Parse Error|Failed to load' })
    foreach ($e in $scriptErrors) { Add-Error "Godot: $e" }
    if ($scriptErrors.Count -eq 0 -and $exit -eq 0) { Write-Ok 'Проект загружается без ошибок скриптов.' }
}

# ------------------------------------------------------------- итог ----
Write-Host ''
foreach ($w in $warnings) { Write-Warn $w }
if ($errors.Count -gt 0) {
    foreach ($e in $errors) { Write-Err $e }
    Write-Err "Проверка провалена: $($errors.Count) ошибок."
    exit 1
}
Write-Ok 'Все проверки пройдены.'
exit 0
