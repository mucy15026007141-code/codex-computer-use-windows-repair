[CmdletBinding()]
param(
    [string]$RuntimeRoot = (Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\runtimes'),
    # Test-only injection: avoids Store package discovery when paired with -SkipPackageDiscovery.
    [string]$SourcePath,
    # Test-only switch: prevents access to the installed Store package.
    [switch]$SkipPackageDiscovery,
    # Test-only switch: exposes pure helpers when dot-sourced by Pester without running diagnostics.
    [switch]$TestFunctionsOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-ExtendedPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if ($full.StartsWith('\\?\')) { return $full }
    return '\\?\' + $full
}
function Get-RuntimeTargetPath([string]$Root, [string]$ContentHash) {
    Join-Path (Join-Path $Root 'cua_node') $ContentHash
}
function Get-Inventory([string]$Path) {
    $files = @(Get-ChildItem -LiteralPath (ConvertTo-ExtendedPath $Path) -File -Recurse -Force)
    [pscustomobject]@{ FileCount = $files.Count; Bytes = ($files | Measure-Object Length -Sum).Sum }
}
function Test-Tree([string]$Source, [string]$Target) {
    if (-not [IO.Directory]::Exists((ConvertTo-ExtendedPath $Target))) { return $false }
    $sourceFiles = @(Get-ChildItem -LiteralPath (ConvertTo-ExtendedPath $Source) -File -Recurse -Force)
    $targetFiles = @(Get-ChildItem -LiteralPath (ConvertTo-ExtendedPath $Target) -File -Recurse -Force)
    if ($sourceFiles.Count -ne $targetFiles.Count) { return $false }
    foreach ($sourceFile in $sourceFiles) {
        $relative = $sourceFile.FullName.Substring((ConvertTo-ExtendedPath $Source).Length).TrimStart('\\')
        $targetFile = Join-Path $Target $relative
        if (-not [IO.File]::Exists((ConvertTo-ExtendedPath $targetFile))) { return $false }
        if ($sourceFile.Length -ne ([IO.FileInfo](ConvertTo-ExtendedPath $targetFile)).Length) { return $false }
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath $sourceFile.FullName).Hash -ne (Get-FileHash -Algorithm SHA256 -LiteralPath (ConvertTo-ExtendedPath $targetFile)).Hash) { return $false }
    }
    return $true
}

if ($TestFunctionsOnly) { return }

if ($SkipPackageDiscovery) {
    if ([string]::IsNullOrWhiteSpace($SourcePath)) { throw '-SourcePath is required with -SkipPackageDiscovery.' }
    $source = $SourcePath
    $codexVersion = 'TestOnly'
}
else {
    $package = @(Get-AppxPackage -Name 'OpenAI.Codex' | Sort-Object Version -Descending | Select-Object -First 1)[0]
    if ($null -eq $package) { throw 'OpenAI.Codex Store package was not found.' }
    $source = Join-Path $package.InstallLocation 'app\resources\cua_node'
    $codexVersion = $package.Version.ToString()
}
if (-not [IO.Directory]::Exists((ConvertTo-ExtendedPath $source))) { throw 'Runtime source directory was not found.' }
$hashScript = Join-Path $PSScriptRoot 'Get-CodexRuntimeHash.ps1'
$key = & $hashScript -SourcePath $source
$target = Get-RuntimeTargetPath -Root $RuntimeRoot -ContentHash $key
$keyFiles = @('manifest.json', ('bin' + [IO.Path]::DirectorySeparatorChar + 'node' + '.exe'), ('bin' + [IO.Path]::DirectorySeparatorChar + 'node_repl' + '.exe'))
$keyState = foreach ($relative in $keyFiles) {
    $sourceFile = Join-Path $source $relative; $targetFile = Join-Path $target $relative
    $present = [IO.File]::Exists((ConvertTo-ExtendedPath $targetFile))
    [pscustomobject]@{ Path = $relative; Exists = $present; SizeMatches = ($present -and ((Get-Item -LiteralPath (ConvertTo-ExtendedPath $sourceFile)).Length -eq (Get-Item -LiteralPath (ConvertTo-ExtendedPath $targetFile)).Length)); Sha256Matches = ($present -and ((Get-FileHash -Algorithm SHA256 -LiteralPath (ConvertTo-ExtendedPath $sourceFile)).Hash -eq (Get-FileHash -Algorithm SHA256 -LiteralPath (ConvertTo-ExtendedPath $targetFile)).Hash)) }
}
$complete = Test-Tree -Source $source -Target $target
[pscustomobject]@{
    CodexVersion = $codexVersion; StorePackagePath = if ($SkipPackageDiscovery) { $null } else { $package.InstallLocation }; SourcePath = $source
    ContentHashKey = $key; TargetPath = $target; SourceInventory = Get-Inventory $source
    TargetInventory = if ([IO.Directory]::Exists((ConvertTo-ExtendedPath $target))) { Get-Inventory $target } else { $null }
    KeyFiles = $keyState; NodeModulesExists = [IO.Directory]::Exists((ConvertTo-ExtendedPath (Join-Path $target 'node_modules')))
    ComputerUseLauncherExists = [IO.File]::Exists((ConvertTo-ExtendedPath (Join-Path $target ('bin' + [IO.Path]::DirectorySeparatorChar + 'codex-computer-use' + '.exe'))))
    HelperTransportExists = [IO.File]::Exists((ConvertTo-ExtendedPath (Join-Path $target 'helper_transport.js')))
    TargetComplete = $complete; RecommendRepair = (-not $complete)
}
