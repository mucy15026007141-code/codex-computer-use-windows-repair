[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Apply,
    [string]$RuntimeRoot = (Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\runtimes'),
    [string]$ReportPath,
    # Test-only injection: avoids Store package discovery when paired with -SkipPackageDiscovery.
    [string]$SourcePath,
    # Test-only switch: prevents access to the installed Store package.
    [switch]$SkipPackageDiscovery,
    # Test-only switch: exposes pure helpers when dot-sourced by Pester without running repair logic.
    [switch]$TestFunctionsOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-ExtendedPath([string]$Path) { $full = [IO.Path]::GetFullPath($Path); if ($full.StartsWith('\\?\')) { return $full }; return '\\?\' + $full }
function Get-RuntimeTargetPath([string]$Root, [string]$ContentHash) { Join-Path (Join-Path $Root 'cua_node') $ContentHash }
function Get-RelativePath51([string]$Base, [string]$Path) {
    if ($Base.StartsWith('\\?\')) { $Base = $Base.Substring(4) }
    if ($Path.StartsWith('\\?\')) { $Path = $Path.Substring(4) }
    $baseUri = New-Object Uri(([IO.Path]::GetFullPath($Base).TrimEnd('\') + '\'))
    $pathUri = New-Object Uri([IO.Path]::GetFullPath($Path))
    [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', [IO.Path]::DirectorySeparatorChar)
}
function Test-ExcludedRuntimePath([string]$Path, [string]$Root, [string]$ContentHash) {
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\\')
    $target = (Get-RuntimeTargetPath $Root $ContentHash).TrimEnd('\\')
    if ($full -eq $target -or $full.StartsWith($target + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true }
    $relative = $full.Substring([IO.Path]::GetFullPath($Root).TrimEnd('\\').Length).TrimStart('\\')
    foreach ($segment in ($relative -split '[\\/]')) {
        if ($segment -like '.staging-*' -or $segment -like '.cua_node-old-*') { return $true }
    }
    return $false
}
function Get-TreeState([string]$Source, [string]$Target) {
    if (-not [IO.Directory]::Exists((ConvertTo-ExtendedPath $Target))) { return [pscustomobject]@{ Exists=$false; Complete=$false; FileCount=0; Bytes=0 } }
    $sourceFiles = @(Get-ChildItem -LiteralPath (ConvertTo-ExtendedPath $Source) -File -Recurse -Force)
    $targetFiles = @(Get-ChildItem -LiteralPath (ConvertTo-ExtendedPath $Target) -File -Recurse -Force)
    if ($sourceFiles.Count -ne $targetFiles.Count) { return [pscustomobject]@{ Exists=$true; Complete=$false; FileCount=$targetFiles.Count; Bytes=0 } }
    $bytes = 0L
    foreach ($sourceFile in $sourceFiles) {
        $relative = Get-RelativePath51 $Source $sourceFile.FullName; $targetFile = Join-Path $Target $relative
        if (-not [IO.File]::Exists((ConvertTo-ExtendedPath $targetFile))) { return [pscustomobject]@{ Exists=$true; Complete=$false; FileCount=$sourceFiles.Count; Bytes=0 } }
        $targetInfo = Get-Item -LiteralPath (ConvertTo-ExtendedPath $targetFile); $bytes += $targetInfo.Length
        if ($sourceFile.Length -ne $targetInfo.Length -or (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceFile.FullName).Hash -ne (Get-FileHash -Algorithm SHA256 -LiteralPath (ConvertTo-ExtendedPath $targetFile)).Hash) { return [pscustomobject]@{ Exists=$true; Complete=$false; FileCount=$sourceFiles.Count; Bytes=$bytes } }
    }
    [pscustomobject]@{ Exists=$true; Complete=$true; FileCount=$sourceFiles.Count; Bytes=$bytes }
}
function Copy-FileStream([string]$Source, [string]$Destination) {
    $parent = Split-Path -Parent $Destination; [IO.Directory]::CreateDirectory((ConvertTo-ExtendedPath $parent)) | Out-Null
    $input = New-Object IO.FileStream((ConvertTo-ExtendedPath $Source), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $output = New-Object IO.FileStream((ConvertTo-ExtendedPath $Destination), [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $buffer = New-Object byte[] 1048576; while (($read = $input.Read($buffer, 0, $buffer.Length)) -gt 0) { $output.Write($buffer, 0, $read) } }
    finally { $output.Dispose(); $input.Dispose() }
}
function Write-RedactedReport([object]$Report, [string]$Path) {
    $text = $Report | ConvertTo-Json -Depth 5
    $text = [regex]::Replace($text, '(?i)[a-z]:\\Users\\[^\\\s]+', 'C:\\Users\\<USER>')
    [IO.File]::WriteAllText([IO.Path]::GetFullPath($Path), $text, (New-Object Text.UTF8Encoding($false)))
}

if ($TestFunctionsOnly) { return }

$exitCode = 1
try {
    if ($SkipPackageDiscovery) {
        if ([string]::IsNullOrWhiteSpace($SourcePath)) { throw '-SourcePath is required with -SkipPackageDiscovery.' }
        $source = $SourcePath; $codexVersion = 'TestOnly'
    }
    else {
        $package = @(Get-AppxPackage -Name 'OpenAI.Codex' | Sort-Object Version -Descending | Select-Object -First 1)[0]
        if ($null -eq $package) { throw 'OpenAI.Codex Store package was not found.' }
        $source = Join-Path $package.InstallLocation 'app\resources\cua_node'; $codexVersion = $package.Version.ToString()
    }
    if (-not [IO.Directory]::Exists((ConvertTo-ExtendedPath $source))) { throw 'Runtime source directory was not found.' }
    $key = & (Join-Path $PSScriptRoot 'Get-CodexRuntimeHash.ps1') -SourcePath $source
    $target = Get-RuntimeTargetPath -Root $RuntimeRoot -ContentHash $key; $state = Get-TreeState $source $target
    $report = [ordered]@{ Mode = if ($Apply) {'Apply'} else {'ReadOnly'}; CodexVersion=$codexVersion; ContentHashKey=$key; TargetExists=$state.Exists; TargetComplete=$state.Complete; Outcome='' }
    if ($state.Complete) { $report.Outcome = 'Already complete; no copy performed.'; $exitCode = 0 }
    elseif ($state.Exists) { throw 'Target exists but verification failed; refusing to overwrite it.' }
    elseif (-not $Apply) { $report.Outcome = 'Repair required; rerun with -Apply after reviewing this report.'; $exitCode = 2 }
    else {
        $blocked = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -in @('Codex','ChatGPT','codex') })
        if ($blocked.Count -gt 0) { throw 'Codex, ChatGPT, or the command-line process is running; refusing to write.' }
        [IO.Directory]::CreateDirectory((ConvertTo-ExtendedPath $RuntimeRoot)) | Out-Null
        $stage = Join-Path $RuntimeRoot ('.cua-stage-' + (Get-Date -Format 'yyyyMMddHHmmssfff')); $stageRuntime = Join-Path $stage 'cua_node'
        foreach ($file in @(Get-ChildItem -LiteralPath (ConvertTo-ExtendedPath $source) -File -Recurse -Force)) { if (-not (Test-ExcludedRuntimePath $file.FullName $RuntimeRoot $key)) { Copy-FileStream $file.FullName (Join-Path $stageRuntime (Get-RelativePath51 $source $file.FullName)) } }
        $stageState = Get-TreeState $source $stageRuntime
        if (-not $stageState.Complete) { throw 'Staging verification failed; staged data was left intact for inspection.' }
        [IO.Directory]::CreateDirectory((ConvertTo-ExtendedPath (Split-Path -Parent $target))) | Out-Null
        [IO.Directory]::Move((ConvertTo-ExtendedPath $stageRuntime), (ConvertTo-ExtendedPath $target))
        if (-not (Get-TreeState $source $target).Complete) { throw 'Post-move verification failed.' }
        $report.Outcome = 'Repair completed and verified.'; $exitCode = 0
    }
    if ($ReportPath) { Write-RedactedReport $report $ReportPath }
    Write-Output $report; Write-Output ("Exit code: {0}" -f $exitCode); exit $exitCode
}
catch {
    if ($ReportPath) { Write-RedactedReport ([ordered]@{ Mode=if($Apply){'Apply'}else{'ReadOnly'}; Outcome='Failed'; Error=$_.Exception.Message }) $ReportPath }
    Write-Error ("Repair failed. Exit code: 1. {0}" -f $_.Exception.Message); exit 1
}
