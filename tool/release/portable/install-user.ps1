# Called by Install.cmd. Per-user install: no admin, nothing outside the user profile.
$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot
$dest = Join-Path $env:LOCALAPPDATA 'Programs\Tidewater'
Get-Process tidewater -ErrorAction SilentlyContinue | Stop-Process -Force
if ($src -ne $dest) {
  New-Item $dest -ItemType Directory -Force | Out-Null
  Copy-Item "$src\*" $dest -Recurse -Force
}
Get-ChildItem $dest -Recurse -File | Unblock-File
$lnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Tidewater.lnk'
$s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$s.TargetPath = Join-Path $dest 'tidewater.exe'
$s.WorkingDirectory = $dest
$s.Save()
Write-Host "Installed to $dest. Start menu: Tidewater."
