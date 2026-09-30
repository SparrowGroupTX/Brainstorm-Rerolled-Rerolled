$ErrorActionPreference = 'Stop'
$taskReceipt = Join-Path $PSScriptRoot 'log_cleanup.json'
if (Test-Path -LiteralPath $taskReceipt) { throw 'Preserve the existing cleanup receipt; do not repeat this operation.' }
$taskTargets = @(
    'C:\Users\trevo\AppData\Roaming\Balatro\advisor_player_log_v1',
    'C:\Users\trevo\AppData\Roaming\Balatro\advisor_player_log_v2'
)
$taskFiles = @()
foreach ($taskDirectory in $taskTargets) {
    if (-not (Test-Path -LiteralPath $taskDirectory)) { continue }
    $taskRootItem = Get-Item -LiteralPath $taskDirectory -Force
    if (-not $taskRootItem.PSIsContainer -or ($taskRootItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Expected an ordinary observation directory.' }
    $taskResolvedRoot = [IO.Path]::GetFullPath($taskRootItem.FullName).TrimEnd('\')
    if ($taskResolvedRoot -ne [IO.Path]::GetFullPath($taskDirectory).TrimEnd('\')) { throw 'Observation directory resolution changed.' }
    foreach ($taskItem in @(Get-ChildItem -LiteralPath $taskDirectory -Force)) {
        if ($taskFiles.Count -ge 4096) { throw 'Observation cleanup exceeds its file bound.' }
        if ($taskItem.PSIsContainer -or ($taskItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Refusing to follow a nested directory or link.' }
        $taskResolvedFile = [IO.Path]::GetFullPath($taskItem.FullName)
        if ([IO.Path]::GetDirectoryName($taskResolvedFile) -ne $taskResolvedRoot) { throw 'A cleanup target escaped its exact observation directory.' }
        $taskFiles += [ordered]@{path=$taskResolvedFile; bytes=$taskItem.Length; lastWriteUtc=$taskItem.LastWriteTimeUtc.ToString('o'); removed=$false}
    }
}
$taskRecord = [ordered]@{
    schema=1; authorization='User explicitly requested: And wipe all previous logs clean please.'
    scope='Direct regular files in advisor_player_log_v1 and advisor_player_log_v2 only. No saves, checkpoints, profiles, repository evidence or game control.'
    startedUtc=[DateTime]::UtcNow.ToString('o'); status='targets_verified_before_deletion'; files=$taskFiles
    totalBytesBefore=($taskFiles | Measure-Object -Property bytes -Sum).Sum; removedFiles=0; removedBytes=0
}
$taskRecord | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $taskReceipt -Encoding utf8
try {
    foreach ($taskEntry in $taskFiles) {
        $taskCurrent = Get-Item -LiteralPath $taskEntry.path -Force
        if ($taskCurrent.PSIsContainer -or ($taskCurrent.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
            $taskCurrent.Length -ne $taskEntry.bytes -or $taskCurrent.LastWriteTimeUtc.ToString('o') -ne $taskEntry.lastWriteUtc) {
            throw 'A target changed after verification; preserving the remainder.'
        }
        Remove-Item -LiteralPath $taskEntry.path -Force
        if (Test-Path -LiteralPath $taskEntry.path) { throw 'Observation removal could not be verified.' }
        $taskEntry.removed=$true
        $taskRecord.removedFiles++
        $taskRecord.removedBytes += $taskEntry.bytes
        $taskRecord | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $taskReceipt -Encoding utf8
    }
    $taskRemaining = @()
    foreach ($taskDirectory in $taskTargets) {
        if (Test-Path -LiteralPath $taskDirectory) { $taskRemaining += @(Get-ChildItem -LiteralPath $taskDirectory -Force | Select-Object FullName,Length) }
    }
    $taskRecord.remainingEntries=$taskRemaining
    $taskRecord.status= if ($taskRemaining.Count -eq 0) { 'complete_directories_empty' } else { 'new_entries_preserved' }
} catch {
    $taskRecord.status='stopped_with_error'; $taskRecord.error=$_.Exception.Message
    throw
} finally {
    $taskRecord.finishedUtc=[DateTime]::UtcNow.ToString('o')
    $taskRecord | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $taskReceipt -Encoding utf8
}
$taskRecord | Select-Object status,removedFiles,removedBytes,remainingEntries | ConvertTo-Json -Depth 4
