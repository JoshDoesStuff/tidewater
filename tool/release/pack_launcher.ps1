# Packs dist\Tidewater (made by build_portable.ps1) into one file: dist\Tidewater.exe = launcher + app folder + trailer.
#   .\tool\release\pack_launcher.ps1
# Payload (read by tool/release/launcher/launcher.cpp): u32 len + utf8 version, u32 file count, then per file
# u32 len + utf8 relative path, u64 size, bytes. Trailer: u64 payload offset + "TWPACK01".
param([string]$OutDir = 'dist')
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root
$app = Join-Path $root "$OutDir\Tidewater"
if (-not (Test-Path (Join-Path $app 'tidewater.exe'))) { throw "No app in $app (run build_portable.ps1 first)" }

$build = Join-Path $root 'build\launcher'
cmake -S tool/release/launcher -B $build -A x64; if ($LASTEXITCODE) { throw 'cmake configure failed' }
cmake --build $build --config Release; if ($LASTEXITCODE) { throw 'cmake build failed' }
$launcher = Join-Path $build 'Release\tidewater_launcher.exe'

# A new version folder per build; uncommitted local changes add a timestamp so a repack never reuses a stale unpack.
$pub = ((Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value -split '\+')[0]
$sha = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { git rev-parse HEAD }
$version = "$pub-$($sha.Substring(0, 7))"
if (-not $env:GITHUB_SHA -and (git status --porcelain)) { $version += '-' + (Get-Date -Format 'yyyyMMddHHmmss') }

$skip = 'Install.cmd', 'install-user.ps1'
$files = @(Get-ChildItem $app -Recurse -File | Where-Object { $_.DirectoryName -ne $app -or $skip -notcontains $_.Name })

$out = Join-Path $root "$OutDir\Tidewater.exe"
Copy-Item $launcher $out -Force
$fs = [IO.File]::Open($out, [IO.FileMode]::Append)
$w = New-Object IO.BinaryWriter($fs)
$utf8 = New-Object Text.UTF8Encoding($false)
function Write-Str([string]$s) { $b = $utf8.GetBytes($s); $w.Write([uint32]$b.Length); $w.Write($b) }
$offset = [uint64]$fs.Position
Write-Str $version
$w.Write([uint32]$files.Count)
foreach ($f in $files) {
  Write-Str $f.FullName.Substring($app.Length + 1)
  $w.Write([uint64]$f.Length)
  $w.Flush()
  $in = [IO.File]::OpenRead($f.FullName)
  $in.CopyTo($fs)
  $in.Close()
}
$w.Write($offset)
$w.Write([Text.Encoding]::ASCII.GetBytes('TWPACK01'))
$w.Close()
Write-Host ("One-exe build: {0} ({1}, {2} files, {3:N0} MB)" -f $out, $version, $files.Count, ((Get-Item $out).Length / 1MB))
