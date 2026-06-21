$state = komorebic state | ConvertFrom-Json
$monitorCount = @($state.monitors.elements).Count

if ($monitorCount -ge 3) {
    komorebic ensure-named-workspaces 0 I1 I2 I3
    komorebic ensure-named-workspaces 1 E4 E5 E6
    komorebic ensure-named-workspaces 2 E7 E8 E9
} elseif ($monitorCount -ge 2) {
    komorebic ensure-named-workspaces 0 I1 I2 I3
    komorebic ensure-named-workspaces 1 E4 E5 E6
} else {
    komorebic ensure-named-workspaces 0 I1 I2 I3
}
