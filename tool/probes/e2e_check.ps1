# Reads Tidewater's Windows media session and drives it from outside, like a
# keyboard's media keys would. Run while tool/probes/e2e_main.dart is playing.
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
$mgrType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]
$propType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]

function Get-Session {
  $mgr = Await ($mgrType::RequestAsync()) $mgrType
  foreach ($s in $mgr.GetSessions()) { if ($s.SourceAppUserModelId -like '*tidewater*') { return $s } }
}
function Show($label) {
  $s = Get-Session
  if (-not $s) { Write-Output "$label : NO SESSION"; return }
  $p = Await ($s.TryGetMediaPropertiesAsync()) $propType
  $pb = $s.GetPlaybackInfo()
  Write-Output ("{0,-22}: '{1}' by '{2}' [{3}] thumbnail={4}" -f $label, $p.Title, $p.Artist, $pb.PlaybackStatus, ($null -ne $p.Thumbnail))
}

Show 'at start'
$s = Get-Session
$null = Await ($s.TryPauseAsync()) ([bool]); Start-Sleep -Milliseconds 1200; Show 'after media-key Pause'
$null = Await ($s.TryPlayAsync()) ([bool]); Start-Sleep -Milliseconds 1200; Show 'after media-key Play'
$null = Await ($s.TrySkipNextAsync()) ([bool]); Start-Sleep -Milliseconds 2500; Show 'after media-key Next'
$null = Await ($s.TrySkipNextAsync()) ([bool]); Start-Sleep -Milliseconds 2500; Show 'after Next again'
$null = Await ($s.TrySkipPreviousAsync()) ([bool]); Start-Sleep -Milliseconds 2500; Show 'after media-key Previous'
