param(
    [ValidateSet('next','previous')]
    [string]$Direction = 'next'
)

$log = Join-Path $env:LOCALAPPDATA 'komorebi\workspace-cycle.log'

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $log -Value "$ts $Message"
}

try {
    $state = komorebic state | ConvertFrom-Json
    $monitorCount  = @($state.monitors.elements).Count
    $monitor       = [int]$state.monitors.focused
    $workspace     = [int]$state.monitors.elements[$monitor].workspaces.focused

    $workspacesPerMonitor = 3
    $total   = $monitorCount * $workspacesPerMonitor
    $current = $monitor * $workspacesPerMonitor + $workspace

    if ($Direction -eq 'next') {
        $next = ($current + 1) % $total
    } else {
        $next = ($current - 1 + $total) % $total
    }

    $nextMonitor   = [int]($next / $workspacesPerMonitor)
    $nextWorkspace = $next % $workspacesPerMonitor

    komorebic focus-monitor-workspace $nextMonitor $nextWorkspace

    Write-Log "ok direction=$Direction monitor=$monitor workspace=$workspace -> $nextMonitor/$nextWorkspace"
} catch {
    Write-Log "error direction=$Direction message=$($_.Exception.Message)"
}
