# Builds a portable Windows zip: the release folder, the MSVC runtime DLLs next to tidewater.exe
# (so the target PC needs no VC++ redistributable), and Install.cmd for a per-user install without admin.
#   .\tool\release\build_portable.ps1            -> dist\Tidewater-<version>-portable.zip
#   .\tool\release\build_portable.ps1 -NoBuild   (zip the last release build)
param([switch]$NoBuild, [string]$OutDir = 'dist')
$ErrorActionPreference = 'Stop'
# Append (never replace): CI adds flutter to the process PATH only; a fresh rustup install is only in the registry.
$env:Path += ";" + [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User") + ";$env:USERPROFILE\.cargo\bin"
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root

if (-not $NoBuild) {
  flutter pub get; if ($LASTEXITCODE) { throw 'flutter pub get failed' }
  flutter build windows --release; if ($LASTEXITCODE) { throw 'flutter build windows failed' }
}
$release = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $release 'tidewater.exe'))) { throw "No release build in $release" }

$version = ((Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value -split '\+')[0]
$stage = Join-Path $root "$OutDir\Tidewater"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
Copy-Item $release $stage -Recurse

# App-local MSVC runtime: the Visual Studio redist folder first, System32 as the fallback.
$dlls = 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll'
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$crt = $null
if (Test-Path $vswhere) {
  $vs = & $vswhere -latest -products * -property installationPath
  if ($vs) {
    $crt = Get-ChildItem "$vs\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT" -Directory -ErrorAction SilentlyContinue |
      Sort-Object FullName -Descending | Select-Object -First 1
  }
}
foreach ($d in $dlls) {
  $src = if ($crt -and (Test-Path "$($crt.FullName)\$d")) { "$($crt.FullName)\$d" } else { "$env:WINDIR\System32\$d" }
  if (-not (Test-Path $src)) { throw "Missing $d (install the VC++ redistributable on this PC)" }
  Copy-Item $src $stage
}

Copy-Item (Join-Path $PSScriptRoot 'portable\*') $stage
$zip = Join-Path $root "$OutDir\Tidewater-$version-portable.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $stage -DestinationPath $zip
Write-Host "Portable zip: $zip"
