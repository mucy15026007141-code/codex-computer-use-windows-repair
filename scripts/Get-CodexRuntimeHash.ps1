[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SourcePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-ExtendedPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if ($full.StartsWith('\\?\')) { return $full }
    return '\\?\' + $full
}

$names = @(
    'manifest.json',
    ('bin' + [IO.Path]::DirectorySeparatorChar + 'node' + '.exe'),
    ('bin' + [IO.Path]::DirectorySeparatorChar + 'node_repl' + '.exe')
)
$builder = New-Object IO.MemoryStream
$utf8 = New-Object Text.UTF8Encoding($false)
try {
    foreach ($relative in $names) {
        $path = Join-Path $SourcePath $relative
        if (-not [IO.File]::Exists((ConvertTo-ExtendedPath $path))) {
            throw "Required content-key file is missing: $relative"
        }
        $line = $relative.Replace([IO.Path]::DirectorySeparatorChar, '/') + [char]0 +
            ((Get-FileHash -Algorithm SHA256 -LiteralPath (ConvertTo-ExtendedPath $path)).Hash.ToLowerInvariant()) + [char]0
        $bytes = $utf8.GetBytes($line)
        $builder.Write($bytes, 0, $bytes.Length)
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $digest = $sha.ComputeHash($builder.ToArray()) }
    finally { $sha.Dispose() }
    (($digest | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 16)
}
finally {
    $builder.Dispose()
}
