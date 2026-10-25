# Runs tool/perf_real_main.dart in profile mode and prints the report.
#   .\tool\run_perf_real.ps1 -Only scroll,np -Url https://server -User u -Pass p
# Without -Url it uses the public Navidrome demo.
param([string]$Only = '', [string]$Url = '', [string]$User = '', [string]$Pass = '', [int]$TimeoutSeconds = 600)
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
Get-Process tidewater, flutter, dart -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$args = @('run', '-d', 'windows', '--profile', '--no-pub', '-t', 'tool/perf_real_main.dart')
if ($Url) { $args += "--dart-define=TW_URL=$Url", "--dart-define=TW_USER=$User", "--dart-define=TW_PASS=$Pass" }
if ($Only) { $args += "--dart-define=TW_ONLY=$Only" }
$out = Join-Path $env:TEMP 'tw_perf_real.txt'
$p = Start-Process -FilePath 'flutter.bat' -ArgumentList $args -RedirectStandardOutput $out -RedirectStandardError "$out.err" -PassThru -WindowStyle Hidden
$null = $p.WaitForExit($TimeoutSeconds * 1000)
Get-Content $out | Select-String -Pattern '=====|^\[|^   (build|raster|total)|no synced|rror' | ForEach-Object { $_.Line }
Get-Process tidewater, flutter, dart -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
