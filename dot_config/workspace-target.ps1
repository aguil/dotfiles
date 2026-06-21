param(
    [ValidateSet('focus','move')]
    [string]$Action,

    [ValidateRange(1, 9)]
    [int]$Slot
)

$state = komorebic state | ConvertFrom-Json
$monitorCount = @($state.monitors.elements).Count

if ($monitorCount -ge 3) {
    $targets = @('I1', 'I2', 'I3', 'E4', 'E5', 'E6', 'E7', 'E8', 'E9')
} elseif ($monitorCount -ge 2) {
    $targets = @('I1', 'I2', 'I3', 'E4', 'E5', 'E6', 'I1', 'I2', 'I3')
} else {
    $targets = @('I1', 'I2', 'I3', 'I1', 'I2', 'I3', 'I1', 'I2', 'I3')
}

$target = $targets[$Slot - 1]

if ($Action -eq 'focus') {
    komorebic focus-named-workspace $target
} else {
    komorebic move-to-named-workspace $target
}
