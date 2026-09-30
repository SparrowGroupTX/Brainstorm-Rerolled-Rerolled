param(
    [string]$Target = 'C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm',
    [string]$Source = '',
    [string]$NativeFile = 'Immolate-v2.16.dll'
)
$ErrorActionPreference = 'Stop'
$sourceRoot = if ($Source) { [IO.Path]::GetFullPath($Source) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\Brainstorm')) }
$coreText = Get-Content -LiteralPath (Join-Path $sourceRoot 'Core\Brainstorm.lua') -Raw
if ($coreText -notmatch 'Brainstorm.VERSION\s*=\s*"Brainstorm v([^"]+)"') { throw 'Cannot read source version.' }
$releaseVersion = $Matches[1]
if ([IO.Path]::GetFileName($NativeFile) -ne $NativeFile -or !$NativeFile.EndsWith('.dll')) { throw 'Expected a native DLL filename.' }
$targetRoot = [IO.Path]::GetFullPath($Target)
if (!(Test-Path -LiteralPath (Join-Path $targetRoot 'Core\Brainstorm.lua'))) {
    throw 'Expected an existing Brainstorm installation.'
}
$configPath = Join-Path $targetRoot 'config.lua'
$configBefore = if (Test-Path -LiteralPath $configPath) { (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash } else { $null }
$relativeFiles = @(Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'Advisor') -Filter '*.lua' -File | Sort-Object Name | ForEach-Object { 'Advisor\' + $_.Name })
$relativeFiles += @(Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'Core') -Filter '*.lua' -File | Where-Object { $_.Name -ne 'Brainstorm.lua' } | Sort-Object Name | ForEach-Object { 'Core\' + $_.Name })
$relativeFiles += @(Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'UI') -Filter '*.lua' -File | Sort-Object Name | ForEach-Object { 'UI\' + $_.Name })
$relativeFiles += @('steamodded_compat.lua', $NativeFile, 'Core\Brainstorm.lua')
foreach ($relative in $relativeFiles) {
    if (!(Test-Path -LiteralPath (Join-Path $sourceRoot $relative) -PathType Leaf)) { throw "Missing source: $relative" }
}
$backupRoot = Join-Path $targetRoot ('deployment-backups\advisor-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backupRoot | Out-Null
$records = @()
# Back up the complete selected set before installing anything. No config or
# save is copied over, and no process/window is started or stopped.
foreach ($relative in $relativeFiles) {
    $dest = Join-Path $targetRoot $relative
    $oldHash = $null
    if (Test-Path -LiteralPath $dest) {
        $oldHash = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
        $backupPath = Join-Path $backupRoot $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
        Copy-Item -LiteralPath $dest -Destination $backupPath
    }
    $records += [ordered]@{ path = $relative; before = $oldHash; after = (Get-FileHash -LiteralPath (Join-Path $sourceRoot $relative) -Algorithm SHA256).Hash }
}
foreach ($record in $records) {
    $dest = Join-Path $targetRoot $record.path
    New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
    # Identical binaries may already be loaded by the running game. Verify and
    # leave them in place; changed native builds must use a new sidecar name.
    if ($record.before -ne $record.after) {
        if ($record.path.EndsWith('.dll') -and $record.before) { throw 'Refusing to overwrite an existing native DLL; use a new sidecar filename.' }
        Copy-Item -LiteralPath (Join-Path $sourceRoot $record.path) -Destination $dest -Force
    }
    if ((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -ne $record.after) { throw "Installed hash mismatch: $($record.path)" }
}
$configAfter = if (Test-Path -LiteralPath $configPath) { (Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash } else { $null }
if ($configBefore -ne $configAfter) { throw 'Configuration changed during deployment; inspect concurrent user changes.' }
$manifest = [ordered]@{ version = $releaseVersion; nativeFile = $NativeFile; installedAt = (Get-Date -Format o); target = $targetRoot; backup = $backupRoot; configSHA256 = $configAfter; files = $records; activation = 'Next normal game restart; no process controlled' }
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backupRoot 'deployment.json') -Encoding utf8
$manifest | ConvertTo-Json -Depth 5
