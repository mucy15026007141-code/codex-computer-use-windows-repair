$repositoryRoot = Split-Path -Parent $PSScriptRoot
$hashScript = Join-Path $repositoryRoot 'scripts\Get-CodexRuntimeHash.ps1'
$testScript = Join-Path $repositoryRoot 'scripts\Test-CodexComputerUseRuntime.ps1'
$repairScript = Join-Path $repositoryRoot 'scripts\Repair-CodexComputerUseRuntime.ps1'

function New-TestRuntimeSource([string]$Root) {
    $source = Join-Path $Root 'source'
    $bin = Join-Path $source 'bin'
    [IO.Directory]::CreateDirectory($bin) | Out-Null
    [IO.File]::WriteAllText((Join-Path $source 'manifest.json'), '{"test":true}', (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllBytes((Join-Path $bin ('node' + '.exe')), [byte[]](1,2,3,4))
    [IO.File]::WriteAllBytes((Join-Path $bin ('node_repl' + '.exe')), [byte[]](5,6,7,8))
    return $source
}

function Get-IndependentContentHash([string]$Source) {
    $ordered = @('manifest.json', ('bin' + [IO.Path]::DirectorySeparatorChar + 'node' + '.exe'), ('bin' + [IO.Path]::DirectorySeparatorChar + 'node_repl' + '.exe'))
    $encoding = New-Object Text.UTF8Encoding($false)
    $stream = New-Object IO.MemoryStream
    try {
        foreach ($relative in $ordered) {
            $fileHash = (Get-FileHash -LiteralPath (Join-Path $Source $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
            $bytes = $encoding.GetBytes($relative.Replace([IO.Path]::DirectorySeparatorChar, '/') + [char]0 + $fileHash + [char]0)
            $stream.Write($bytes, 0, $bytes.Length)
        }
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hex = (($sha.ComputeHash($stream.ToArray()) | ForEach-Object { $_.ToString('x2') }) -join '') }
        finally { $sha.Dispose() }
        return $hex.Substring(0, 16)
    }
    finally { $stream.Dispose() }
}

Describe 'Codex Computer Use runtime scripts in isolated temporary directories' {
    BeforeAll {
        . $testScript -TestFunctionsOnly
        . $repairScript -TestFunctionsOnly
    }

    It 'computes the specified content hash and truncates it to 16 characters' {
        $source = New-TestRuntimeSource (Join-Path $TestDrive 'hash')
        $expected = Get-IndependentContentHash $source
        $actual = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hashScript -SourcePath $source
        $LASTEXITCODE | Should Be 0
        $actual | Should Be $expected
        $actual.Length | Should Be 16
    }

    It 'uses runtimes cua_node hash as the target layout' {
        $root = Join-Path $TestDrive 'runtimes'; $key = '0123456789abcdef'
        $actual = Get-RuntimeTargetPath -Root $root -ContentHash $key
        $expected = Join-Path (Join-Path $root 'cua_node') $key
        $oldLayout = Join-Path (Join-Path $root $key) 'cua_node'
        $actual | Should Be $expected
        ($actual -eq $oldLayout) | Should Be $false
    }

    It 'converts local paths to a single extended path prefix' {
        (ConvertTo-ExtendedPath 'C:\runtime\deep') | Should Be '\\?\C:\runtime\deep'
        (ConvertTo-ExtendedPath '\\?\C:\runtime\deep') | Should Be '\\?\C:\runtime\deep'
    }

    It 'excludes target hash, staging, and old directories but not normal files' {
        $root = Join-Path $TestDrive 'runtimes'; $key = '0123456789abcdef'
        (Test-ExcludedRuntimePath (Join-Path (Join-Path (Join-Path $root 'cua_node') $key) 'file.txt') $root $key) | Should Be $true
        (Test-ExcludedRuntimePath (Join-Path $root '.staging-old\file.txt') $root $key) | Should Be $true
        (Test-ExcludedRuntimePath (Join-Path $root '.cua_node-old-copy\file.txt') $root $key) | Should Be $true
        (Test-ExcludedRuntimePath (Join-Path $root 'ordinary\file.txt') $root $key) | Should Be $false
    }

    It 'keeps default repair read-only with an isolated missing target' {
        $case = Join-Path $TestDrive 'readonly'; $source = New-TestRuntimeSource $case; $root = Join-Path $case 'runtimes'
        $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $repairScript -SkipPackageDiscovery -SourcePath $source -RuntimeRoot $root 2>&1
        $LASTEXITCODE | Should Be 2
        (Test-Path -LiteralPath $root) | Should Be $false
        @(Get-ChildItem -LiteralPath $case -Directory -Filter '.cua-stage-*' -ErrorAction SilentlyContinue).Count | Should Be 0
    }

    It 'recognizes an isolated healthy target without recommending repair or creating staging' {
        $case = Join-Path $TestDrive 'healthy'; $source = New-TestRuntimeSource $case; $root = Join-Path $case 'runtimes'
        $key = Get-IndependentContentHash $source; $target = Get-RuntimeTargetPath $root $key
        foreach ($sourceFile in @(Get-ChildItem -LiteralPath $source -File -Recurse)) {
            $relative = $sourceFile.FullName.Substring($source.Length).TrimStart('\\'); $destination = Join-Path $target $relative
            [IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null; [IO.File]::Copy($sourceFile.FullName, $destination)
        }
        (Test-Tree -Source $source -Target $target) | Should Be $true
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $testScript -SkipPackageDiscovery -SourcePath $source -RuntimeRoot $root 2>&1
        $LASTEXITCODE | Should Be 0
        ($output | Out-String) | Should Match 'TargetComplete\s+: True'
        ($output | Out-String) | Should Match 'RecommendRepair\s+: False'
        $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $repairScript -SkipPackageDiscovery -SourcePath $source -RuntimeRoot $root 2>&1
        $LASTEXITCODE | Should Be 0
        @(Get-ChildItem -LiteralPath $root -Directory -Filter '.cua-stage-*' -ErrorAction SilentlyContinue).Count | Should Be 0
    }
}
