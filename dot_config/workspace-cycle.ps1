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
    $monitor = [int]$state.monitors.focused
    $workspace = [int]$state.monitors.elements[$monitor].workspaces.focused

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

    Write-Log "ok direction=$Direction monitor=$monitor workspace=$workspace"
} catch {
    Write-Log "error direction=$Direction message=$($_.Exception.Message)"
}
