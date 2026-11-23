param(
    [ValidateSet('focus','move')]
    [string]$Action,

    [ValidateRange(1, 9)]
    [int]$Slot
)

$state = komorebic state | ConvertFrom-Json
$present = @($state.monitors.elements | ForEach-Object { $_.workspaces.elements.name })

# Slots map to fixed labels. If the monitor that owns a label is disconnected,
# fall back to the matching internal workspace.
$labels = @('I1', 'I2', 'I3', 'E4', 'E5', 'E6', 'E7', 'E8', 'E9')
$fallback = $labels[($Slot - 1) % 3]
$target = @($labels[$Slot - 1], $fallback) | Where-Object { $_ -in $present } | Select-Object -First 1

if (-not $target) {
    exit 0
}

if ($Action -eq 'focus') {
    komorebic focus-named-workspace $target
} else {
    komorebic move-to-named-workspace $target
}
