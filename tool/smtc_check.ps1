# Reads the Windows media sessions through the system API and, for the one
# Tidewater published, prints its title/artist/status/timeline and presses
# Pause, Play and Next on it. Run while tool/smtc_probe_main.dart is running.
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
  })[0]
function Await($op, $type) {
  $t = $asTask.MakeGenericMethod($type).Invoke($null, @($op))
  $null = $t.Wait(-1)
  $t.Result
}
$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties, Windows.Media.Control, ContentType = WindowsRuntime]
$mgr = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
$found = $false
foreach ($s in $mgr.GetSessions()) {
  $props = Await ($s.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
  Write-Output ("SESSION app={0} title='{1}' artist='{2}' album='{3}'" -f $s.SourceAppUserModelId, $props.Title, $props.Artist, $props.AlbumTitle)
  if ($props.Title -ne 'Probe Song') { continue }
  $found = $true
  $pb = $s.GetPlaybackInfo()
  Write-Output ("  status={0} next={1} prev={2} play={3} pause={4}" -f $pb.PlaybackStatus, $pb.Controls.IsNextEnabled, $pb.Controls.IsPreviousEnabled, $pb.Controls.IsPlayEnabled, $pb.Controls.IsPauseEnabled)
  $tl = $s.GetTimelineProperties()
  Write-Output ("  timeline position={0} end={1}" -f $tl.Position, $tl.EndTime)
  foreach ($action in 'TryPauseAsync', 'TryPlayAsync', 'TrySkipNextAsync', 'TrySkipPreviousAsync') {
    $ok = Await ($s.$action()) ([bool])
    Write-Output ("  {0} -> {1}" -f $action, $ok)
    Start-Sleep -Milliseconds 400
  }
}
if (-not $found) { Write-Output 'NOT FOUND: no session titled Probe Song' }
