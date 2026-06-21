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
$monitor  = [int]$s.monitors.focused
$workspace = [int]$s.monitors.elements[$monitor].workspaces.focused

$workspacesPerMonitor = 3
$total = $monitorCount * $workspacesPerMonitor
$current = $monitor * $workspacesPerMonitor + $workspace

if ($Direction -eq 'next') {
    $next = ($current + 1) % $total
} else {
    $next = ($current - 1 + $total) % $total
}

$nextMonitor    = [int]($next / $workspacesPerMonitor)
$nextWorkspace  = $next % $workspacesPerMonitor

komorebic focus-monitor-workspace $nextMonitor $nextWorkspace
