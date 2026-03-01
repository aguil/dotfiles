$state = komorebic state | ConvertFrom-Json
$monitorCount = @($state.monitors.elements).Count

if ($monitorCount -ge 2) {
    komorebic ensure-named-workspaces 0 I1 I2 I3
    komorebic ensure-named-workspaces 1 E1 E2 E3
} else {
    komorebic ensure-named-workspaces 0 I1 I2 I3
}
