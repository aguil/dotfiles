# Restores workspace names, layouts and window placement after a display change.
#
# After a reconnect, komorebi can keep a monitor with no workspaces, in the wrong
# order, without the space reserved for its bar, or as a permanent "UNKNOWN"
# display added before Windows gave it an ID. Windows can also be left unmanaged.
# This waits for Windows and komorebi to settle, then rebuilds komorebi's monitor
# list in place, which also adopts the windows and restarts the bars. Reloading
# komorebi.json is not enough: it only reapplies names and layouts. komorebi is
# restarted only if the rebuild fails. Monitors are never identified by position.
# Does nothing when everything is already right.
#
# komorebi also loses track of which window was where: while docking, it adopts
# each window on whatever monitor it is on at that moment, and windows on hidden
# workspaces can stay cloaked and unmanaged. A rebuild cannot know better, so with
# -Watch this saves the placement while docked, and puts it back after recovery.
param(
    [string]$ConfigPath = (Join-Path $env:USERPROFILE 'komorebi.json'),
    [string]$StartScript = (Join-Path $env:USERPROFILE '.config\start-komorebi.cmd'),
    [string]$DataDir = (Join-Path $env:LOCALAPPDATA 'komorebi'),
    [int]$TimeoutSeconds = 20,
    [int]$PollSeconds = 3,
    [int]$RebuildSeconds = 20,
    [int]$RestartSeconds = 120,
    [int]$RestartCooldownMinutes = 10,
    [string]$WindowScript = (Join-Path $PSScriptRoot 'workspace-window.ps1'),
    # Saves placement until the given process ends.
    [switch]$Watch,
    [int]$ParentPid,
    [int]$WatchSeconds = 10,
    [int]$FreezeMinutes = 10,
    [int]$MaxTicks = 0
)

. $WindowScript
$placementPath = Join-Path $DataDir 'workspace-placement.json'
# Written by workspace-cycle.ahk on every display change; stops saving.
$frozenPath = Join-Path $DataDir 'workspace-placement.frozen'
# Present after a display went away, until placement is restored. Also written by
# workspace-cycle.ahk, which sees displays that are back before this script runs.
$undockedPath = Join-Path $DataDir 'workspace-placement.undocked'

function Write-Log {
    param([string]$Message)
    $line = '{0:yyyy-MM-dd HH:mm:ss} {1}' -f (Get-Date), $Message
    Add-Content -Path (Join-Path $DataDir 'workspace-recover.log') -Value $line
}

# Displays Windows sees now, as device_id -> serial.
function Get-LiveDisplays {
    $displays = @{}
    foreach ($m in Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction Stop) {
        if (-not $m.Active) { continue }
        $id = ($m.InstanceName -replace '^DISPLAY\\', '' -replace '_\d+$', '').Replace('\', '-')
        $displays[$id] = -join ($m.SerialNumberID | Where-Object { $_ } | ForEach-Object { [char]$_ })
    }
    $displays
}

# komorebic fails while komorebi is busy; callers poll again.
function Get-KomorebiState {
    komorebic state 2>$null | ConvertFrom-Json
}

# For callers that cannot go on without a state. Throws if none comes, so that
# nothing after it treats a missing reply as an empty komorebi.
function Wait-KomorebiState {
    for ($i = 0; $i -lt 20; $i++) {
        $state = try { Get-KomorebiState } catch { $null }
        if ($state.monitors.elements) { return $state }
        Start-Sleep -Milliseconds 500
    }
    throw 'komorebi not responding'
}

# Monitors komorebi knows, in its order, with the config index each one matches.
function Get-KomorebiMonitors {
    param($State, $Config)

    foreach ($m in $State.monitors.elements) {
        $match = $Config.display_index_preferences.PSObject.Properties | Where-Object {
            $_.Value -eq $m.device_id -or ($m.serial_number_id -and $_.Value -eq $m.serial_number_id)
        } | Select-Object -First 1
        [PSCustomObject]@{
            DeviceId = $m.device_id
            Serial   = $m.serial_number_id
            Index    = if ($match) { [int]$match.Name } else { $null }
            Spaced   = $null -ne $m.work_area_offset
            Names    = @($m.workspaces.elements | ForEach-Object { "$($_.name)" })
        }
    }
}

# 'ready', or why komorebi's view does not match Windows yet.
function Get-Readiness {
    param($Monitors, $Live, $Config)

    if (-not $Monitors) { return 'komorebi not responding' }
    $wanted = @($Config.display_index_preferences.PSObject.Properties | ForEach-Object { $_.Value })
    $ids = @($Monitors | ForEach-Object { $_.DeviceId })
    foreach ($id in $Live.Keys) {
        if ($id -notin $ids -and ($id -in $wanted -or $Live[$id] -in $wanted)) {
            return 'configured display missing'
        }
    }
    $known = @($Monitors | ForEach-Object { $_.DeviceId } | Sort-Object)
    if (($known -join '|') -ne (@($Live.Keys | Sort-Object) -join '|')) { return 'displays differ' }
    foreach ($m in $Monitors) {
        if ($Live[$m.DeviceId] -and $m.Serial -ne $Live[$m.DeviceId]) { return 'serial missing' }
    }
    'ready'
}

function Test-Labels {
    param($Monitors, $Config)

    foreach ($m in $Monitors) {
        if ($null -eq $m.Index) { continue }
        $want = @($Config.monitors[$m.Index].workspaces | ForEach-Object { "$($_.name)" })
        if (($want -join '|') -ne ($m.Names -join '|')) { return $false }
    }
    $true
}

# Bars reserve their own space, so this only applies while bars are running.
function Test-Spacing {
    param($Monitors, $Config, [bool]$BarsExpected)

    if (-not $BarsExpected) { return $true }
    $bars = @($Config.bar_configurations | Where-Object { $_ }).Count
    foreach ($m in $Monitors) {
        if ($null -ne $m.Index -and $m.Index -lt $bars -and -not $m.Spaced) { return $false }
    }
    $true
}

function Test-Order {
    param($Monitors)

    $indices = @($Monitors | Where-Object { $null -ne $_.Index } | ForEach-Object { $_.Index })
    ($indices -join '|') -eq (@($indices | Sort-Object) -join '|')
}

# True when Windows sees every display in the config.
function Test-AllDisplays {
    param($Live, $Config)

    $seen = @($Live.Keys) + @($Live.Values)
    foreach ($p in $Config.display_index_preferences.PSObject.Properties) {
        if ($p.Value -notin $seen) { return $false }
    }
    $true
}

function Get-FocusedHwnd {
    param($State)

    $m = $State.monitors.elements[$State.monitors.focused]
    $w = $m.workspaces.elements[$m.workspaces.focused]
    if (@($w.containers.elements | Where-Object { $_ }).Count -eq 0) { return 0 }
    $c = $w.containers.elements[$w.containers.focused]
    [long]$c.windows.elements[$c.windows.focused].hwnd
}

# Tiled windows and their workspaces, plus the visible workspaces and the focus.
# Titles are left out on purpose.
function Get-Placement {
    param($State)

    $windows = @()
    $visible = @()
    foreach ($m in $State.monitors.elements) {
        $visible += "$($m.workspaces.elements[$m.workspaces.focused].name)"
        foreach ($w in $m.workspaces.elements) {
            foreach ($c in $w.containers.elements) {
                foreach ($x in $c.windows.elements) {
                    $windows += [PSCustomObject]@{
                        hwnd      = [long]$x.hwnd
                        workspace = "$($w.name)"
                        owner     = Get-WindowOwner $x.hwnd
                    }
                }
            }
        }
    }
    [PSCustomObject]@{
        windows = $windows
        visible = $visible
        focused = $visible[$State.monitors.focused]
        window  = Get-FocusedHwnd $State
    }
}

# Every window komorebi tracks, tiled or not.
function Get-TrackedHwnds {
    param($State)

    foreach ($m in $State.monitors.elements) {
        foreach ($w in $m.workspaces.elements) {
            foreach ($c in @($w.containers.elements) + @($w.monocle_container)) {
                foreach ($x in $c.windows.elements) { [long]$x.hwnd }
            }
            foreach ($x in @($w.floating_windows.elements) + @($w.maximized_window)) {
                if ($x.hwnd) { [long]$x.hwnd }
            }
        }
    }
}

# Saved windows that still exist.
function Get-SavedWindows {
    param($Placement)

    foreach ($w in $Placement.windows) {
        if ($w.owner -and $w.owner -eq (Get-WindowOwner $w.hwnd)) { $w }
    }
}

# Shows saved windows komorebi hid and then forgot, so that it adopts them.
function Show-LostWindows {
    param($Placement, $State)

    # Without a state, every window would look forgotten.
    if (-not $State.monitors.elements) { return }
    $tracked = @(Get-TrackedHwnds $State)
    $shown = 0
    foreach ($w in @(Get-SavedWindows $Placement)) {
        if ([long]$w.hwnd -notin $tracked -and (Test-WindowCloaked $w.hwnd)) {
            if (Show-CloakedWindow $w.hwnd) { $shown++ }
        }
    }
    if ($shown) {
        Write-Log "showed $shown lost window(s)"
        Start-Sleep -Seconds 2
    }
}

# Sends one window to a workspace. komorebic acts on the focused container, so
# nothing is sent unless komorebi and Windows agree that the window has focus.
function Move-Window {
    param([long]$Hwnd, [string]$Workspace)

    for ($i = 0; $i -lt 6; $i++) {
        Set-WindowForeground $Hwnd
        Start-Sleep -Milliseconds 400
        $state = try { Get-KomorebiState } catch { $null }
        # A missing reply is a failed attempt, not a reason to stop.
        if (-not $state.monitors.elements) { continue }
        if ((Get-FocusedHwnd $state) -eq $Hwnd -and (Get-WindowForeground) -eq $Hwnd) {
            komorebic send-to-named-workspace $Workspace 2>$null | Out-Null
            Start-Sleep -Milliseconds 400
            return
        }
    }
}

# True once every saved window that still exists is where it was.
function Restore-Placement {
    param($Placement)

    Show-LostWindows $Placement (Wait-KomorebiState)
    $state = Wait-KomorebiState
    $tiled = @((Get-Placement $state).windows | ForEach-Object { $_.hwnd })
    $tracked = @(Get-TrackedHwnds $state)
    $wanted = @{}
    foreach ($w in @(Get-SavedWindows $Placement)) {
        $hwnd = [long]$w.hwnd
        if (Test-WindowMinimized $hwnd) { continue }
        # Floated, monocle, maximized or hidden to the tray since: leave it alone.
        # One that is visible or cloaked but not tracked was lost, so it counts.
        if ($hwnd -notin $tiled -and ($hwnd -in $tracked -or -not (Test-WindowVisible $hwnd))) { continue }
        $wanted[$hwnd] = $w.workspace
    }

    $moved = $false
    foreach ($m in $state.monitors.elements) {
        foreach ($w in $m.workspaces.elements) {
            foreach ($c in $w.containers.elements) {
                # A stack moves as one, so only move it if all of it belongs there.
                $targets = @($c.windows.elements | ForEach-Object { "$($wanted[[long]$_.hwnd])" } | Sort-Object -Unique)
                if ($targets.Count -ne 1 -or -not $targets[0] -or $targets[0] -eq $w.name) { continue }
                Move-Window $c.windows.elements[$c.windows.focused].hwnd $targets[0]
                $moved = $true
            }
        }
    }

    $now = Get-Placement (Wait-KomorebiState)
    $wantVisible = @($Placement.visible) -join '|'
    if ($moved -or ($now.visible -join '|') -ne $wantVisible) {
        # The focused one last, so that it keeps the focus.
        $views = @($Placement.visible | Where-Object { $_ -ne $Placement.focused }) + @($Placement.focused)
        foreach ($name in $views) {
            komorebic focus-named-workspace $name 2>$null | Out-Null
            Start-Sleep -Milliseconds 300
        }
        $target = $wanted[[long]$Placement.window]
        if ($target -and $target -eq $Placement.focused) {
            Set-WindowForeground $Placement.window
            Start-Sleep -Milliseconds 300
        }
        $now = Get-Placement (Wait-KomorebiState)
    }

    $at = @{}
    foreach ($w in $now.windows) { $at[[long]$w.hwnd] = $w.workspace }
    $right = @($wanted.Keys | Where-Object { $at[$_] -eq $wanted[$_] }).Count
    $screens = ($now.visible -join '|') -eq $wantVisible
    if ($right -eq $wanted.Count -and $screens) {
        Write-Log "placement right: $right window(s)"
        return $true
    }
    Write-Log "placement wrong: $right of $($wanted.Count) window(s) in place, visible workspaces right: $screens"
    $false
}

# Keeps a file that was written again after the given time.
function Remove-Older {
    param([string]$Path, [datetime]$Than)

    $file = Get-Item $Path -ErrorAction SilentlyContinue
    if ($file -and $file.LastWriteTime -lt $Than) { Remove-Item $Path }
}

function Read-Placement {
    if (-not (Test-Path $placementPath)) { return }
    try { Get-Content -Path $placementPath -Raw | ConvertFrom-Json } catch { Write-Log 'saved placement unreadable' }
}

function Test-Healthy {
    param($State, $Config, [bool]$BarsExpected)

    $now = @(Get-KomorebiMonitors $State $Config)
    (Get-Readiness $now (Get-LiveDisplays) $Config) -eq 'ready' -and
        (Test-Order $now) -and (Test-Labels $now $Config) -and (Test-Spacing $now $Config $BarsExpected)
}

function Wait-Healthy {
    param([int]$Seconds, $Config, [bool]$BarsExpected)

    $until = (Get-Date).AddSeconds($Seconds)
    do {
        Start-Sleep -Seconds 2
        try {
            if (Test-Healthy (Get-KomorebiState) $Config $BarsExpected) { return $true }
        } catch {
            # Busy; try again until the time is up.
        }
    } while ((Get-Date) -lt $until)
    $false
}

function Test-Frozen {
    $frozen = Get-Item $frozenPath -ErrorAction SilentlyContinue
    $frozen -and $frozen.LastWriteTime -ge (Get-Date).AddMinutes(-$FreezeMinutes)
}

# Saves placement while every configured display is present and labelled. A
# placement is only written if the next check, without a display change in
# between, finds the same one: at an undock Windows minimizes windows first.
function Start-Watch {
    $mutex = New-Object System.Threading.Mutex($false, 'Local\komorebi-workspace-placement')
    $owned = $false
    try {
        # A previous watcher ends soon after its own parent does.
        try { $owned = $mutex.WaitOne(30000) } catch [System.Threading.AbandonedMutexException] { $owned = $true }
        if (-not $owned) { return }
        $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        $candidate = ''
        $saved = ''
        $tick = 0
        while (-not $ParentPid -or (Get-Process -Id $ParentPid -ErrorAction SilentlyContinue)) {
            $json = ''
            try {
                if (-not (Test-Frozen)) {
                    $state = Get-KomorebiState
                    if (-not $state.is_paused -and (Test-AllDisplays (Get-LiveDisplays) $config) -and
                        (Test-Healthy $state $config $false)) {
                        $json = Get-Placement $state | ConvertTo-Json -Depth 4 -Compress
                    }
                }
                if ($json -and $json -eq $candidate -and $json -ne $saved -and -not (Test-Frozen)) {
                    Set-Content -Path "$placementPath.tmp" -Value $json
                    Move-Item -Path "$placementPath.tmp" -Destination $placementPath -Force
                    $saved = $json
                }
            } catch {
                # komorebi is down or busy; nothing to save.
                $json = ''
            }
            $candidate = $json
            $tick++
            if ($MaxTicks -and $tick -ge $MaxTicks) { return }
            Start-Sleep -Seconds $WatchSeconds
        }
    } finally {
        if ($owned) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

function Restart-Komorebi {
    param([string]$Reason)

    $stamp = Join-Path $DataDir 'workspace-recover.restart'
    if ((Test-Path $stamp) -and
        (Get-Item $stamp).LastWriteTime -gt (Get-Date).AddMinutes(-$RestartCooldownMinutes)) {
        Write-Log "restart skipped, cooling down: $Reason"
        return $false
    }
    Set-Content -Path $stamp -Value $Reason
    Write-Log "restarting komorebi: $Reason"
    Start-Process -FilePath $env:ComSpec -ArgumentList "/c `"$StartScript`"" -WindowStyle Hidden | Out-Null
    $true
}

# Rebuilds komorebi's monitor list without restarting it, matching by serial.
# True once everything but the placement is right.
function Invoke-Rebuild {
    param([string]$Reason, $Config, [bool]$BarsExpected)

    Write-Log "rebuilding monitors: $Reason"
    komorebic replace-configuration $ConfigPath 2>$null | Out-Null
    if (Wait-Healthy $RebuildSeconds $Config $BarsExpected) {
        Write-Log 'after rebuild: labels and bar spacing right'
        return $true
    }
    if (-not (Restart-Komorebi "rebuild did not help: $Reason")) { return $false }
    if (Wait-Healthy $RestartSeconds $Config $BarsExpected) {
        Write-Log 'after restart: labels and bar spacing right'
        return $true
    }
    Write-Log "after restart: still wrong after ${RestartSeconds}s"
    $false
}

if ($Watch) {
    Start-Watch
    return
}

$mutex = New-Object System.Threading.Mutex($false, 'Local\komorebi-workspace-recover')
$owned = $false
try {
    # Wait for an earlier run, since the displays changed again after it started.
    try { $owned = $mutex.WaitOne(180000) } catch [System.Threading.AbandonedMutexException] { $owned = $true }
    if (-not $owned) { return }
    $started = Get-Date

    # Read once: a rebuild stops the bars for a moment.
    $barsExpected = @(Get-Process -Name komorebi-bar -ErrorAction SilentlyContinue).Count -gt 0
    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $previous = ''
    $status = 'no data'

    # Act only once two polls in a row agree that komorebi has caught up.
    while ($true) {
        try {
            $live = Get-LiveDisplays
            $monitors = @(Get-KomorebiMonitors (Get-KomorebiState) $config)
            $status = Get-Readiness $monitors $live $config
        } catch {
            $monitors = @()
            $status = "query failed: $($_.Exception.Message)"
        }

        $snapshot = "$status " + (@($monitors | ForEach-Object { "$($_.DeviceId)=$($_.Serial)" }) -join '|')
        if ($status -eq 'ready' -and $snapshot -eq $previous) { break }
        $previous = $snapshot

        if ((Get-Date) -ge $deadline) { break }
        Start-Sleep -Seconds $PollSeconds
    }

    $docked = Test-AllDisplays (Get-LiveDisplays) $config
    if (-not $docked) { Set-Content -Path $undockedPath -Value (Get-Date -Format s) }

    $problem = ''
    if ($status -in 'serial missing', 'configured display missing') {
        $problem = $status
    } elseif ($status -ne 'ready') {
        Write-Log "gave up after ${TimeoutSeconds}s: $status"
        return
    } elseif (-not (Test-Order $monitors)) {
        $problem = 'monitors out of order'
    } elseif (-not (Test-Labels $monitors $config)) {
        $problem = 'labels wrong'
    } elseif (-not (Test-Spacing $monitors $config $barsExpected)) {
        $problem = 'bar spacing missing'
    }

    $placement = if ($docked) { Read-Placement }
    if ($problem) {
        # Before the rebuild, which only adopts windows it can see.
        if ($placement) {
            $state = try { Get-KomorebiState } catch { $null }
            Show-LostWindows $placement $state
        }
        if (-not (Invoke-Rebuild $problem $config $barsExpected)) { return }
    }
    # Otherwise nothing moved the windows, and the user may just have.
    if ($docked -and ($problem -or (Test-Path $undockedPath))) {
        # If this fails or throws, saving stays paused so the good copy survives.
        if ($placement -and -not (Restore-Placement $placement)) { return }
        Remove-Older $undockedPath $started
    }

    # Resume saving, unless the displays changed again meanwhile.
    Remove-Older $frozenPath $started
} catch {
    Write-Log "error: $($_.Exception.Message)"
} finally {
    if ($owned) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
