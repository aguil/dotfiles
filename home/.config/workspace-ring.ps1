param(
    [ValidateSet('next','previous')]
    [string]$Direction = 'next'
)

$stateDir = Join-Path $env:LOCALAPPDATA 'komorebi'

if (-not (Test-Path $stateDir)) {
    New-Item -Path $stateDir -ItemType Directory | Out-Null
}

$s = komorebic state | ConvertFrom-Json
$monitorCount = @($s.monitors.elements).Count
$monitor = [int]$s.monitors.focused
$workspace = [int]$s.monitors.elements[$monitor].workspaces.focused

if ($monitorCount -lt 2) {
    if ($Direction -eq 'next') {
        if ($workspace -lt 2) {
            komorebic focus-monitor-workspace 0 ($workspace + 1)
        } else {
            komorebic focus-monitor-workspace 0 0
        }
    } else {
        if ($workspace -gt 0) {
            komorebic focus-monitor-workspace 0 ($workspace - 1)
        } else {
            komorebic focus-monitor-workspace 0 2
        }
    }

    return
}

if ($Direction -eq 'next') {
    if ($monitor -eq 0) {
        if ($workspace -lt 2) {
            komorebic focus-monitor-workspace 0 ($workspace + 1)
        } else {
            komorebic focus-monitor-workspace 1 0
        }
    } else {
        if ($workspace -lt 2) {
            komorebic focus-monitor-workspace 1 ($workspace + 1)
        } else {
            komorebic focus-monitor-workspace 0 0
        }
    }
} else {
    if ($monitor -eq 1) {
        if ($workspace -gt 0) {
            komorebic focus-monitor-workspace 1 ($workspace - 1)
        } else {
            komorebic focus-monitor-workspace 0 2
        }
    } else {
        if ($workspace -gt 0) {
            komorebic focus-monitor-workspace 0 ($workspace - 1)
        } else {
            komorebic focus-monitor-workspace 1 2
        }
    }
}
