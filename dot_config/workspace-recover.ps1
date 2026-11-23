# Restores workspace names, layouts and window placement after a display change.
#
# After a reconnect, komorebi can keep a monitor with no workspaces, in the wrong
# order, without the space reserved for its bar, or as a permanent "UNKNOWN"
# display added before Windows gave it an ID. Windows can also be left unmanaged.
# This waits for Windows and komorebi to settle, then rebuilds komorebi's monitor
# list in place, which also adopts the windows and restarts the bars. Reloading
# komorebi.json is not enough: it only reapplies names and layouts. A bar that
# does not come back from the rebuild is started again, and komorebi is restarted
# only if the rebuild still fails. Monitors are never identified by position.
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
    [int]$BarSeconds = 15,
    [int]$BarAfterSeconds = 5,
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
# The placement the last restore started from, in case that went wrong.
$previousPath = Join-Path $DataDir 'workspace-placement.previous.json'
# Written by workspace-cycle.ahk on every display change; stops saving.
$frozenPath = Join-Path $DataDir 'workspace-placement.frozen'
# Present after a configured display went away or start-komorebi.cmd ran, until
# placement is restored. Also written by workspace-cycle.ahk, which sees displays
# that are back before this script runs.
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

# '' when komorebi's monitors are in order, labelled and spaced, else what is wrong.
function Get-Fault {
    param($Monitors, $Config, [bool]$BarsExpected)

    if (-not (Test-Order $Monitors)) { return 'monitors out of order' }
    if (-not (Test-Labels $Monitors $Config)) { return 'labels wrong' }
    if (-not (Test-Spacing $Monitors $Config $BarsExpected)) { return 'bar spacing missing' }
    ''
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
# Titles are left out on purpose, and so are displays that are not in the config:
# their workspaces have no name to go back to.
function Get-Placement {
    param($State, $Config)

    $windows = @()
    $visible = @()
    $focused = ''
    $window = 0
    $known = @(Get-KomorebiMonitors $State $Config)
    for ($i = 0; $i -lt $known.Count; $i++) {
        if ($null -eq $known[$i].Index) { continue }
        $m = @($State.monitors.elements)[$i]
        $name = "$($m.workspaces.elements[$m.workspaces.focused].name)"
        $visible += $name
        if ($i -eq $State.monitors.focused) {
            $focused = $name
            $window = Get-FocusedHwnd $State
        }
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
        focused = $focused
        window  = $window
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

# Reopens saved windows that the undock minimized, and gives komorebi time to
# adopt them. They were open when saved, so nothing else explains it, except the
# user minimizing one while undocked.
function Show-MinimizedWindows {
    param($Placement)

    $shown = @()
    foreach ($w in @(Get-SavedWindows $Placement)) {
        if ((Test-WindowMinimized $w.hwnd) -and (Test-WindowVisible $w.hwnd)) {
            Show-MinimizedWindow $w.hwnd
            $shown += [long]$w.hwnd
        }
    }
    if (-not $shown) { return }
    Write-Log "reopened $($shown.Count) minimized window(s)"
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 500
        $tracked = @(Get-TrackedHwnds (Wait-KomorebiState))
        $waiting = @($shown | Where-Object { $_ -notin $tracked -or (Test-WindowMinimized $_) })
        if (-not $waiting) { return }
    }
}

# True once every saved window that still exists is where it was.
function Restore-Placement {
    param($Placement, $Config)

    # After a reboot, for example.
    if (-not @(Get-SavedWindows $Placement)) {
        Write-Log 'no saved window exists any more'
        return $true
    }
    Show-LostWindows $Placement (Wait-KomorebiState)
    Show-MinimizedWindows $Placement
    $state = Wait-KomorebiState
    $tiled = @((Get-Placement $state $Config).windows | ForEach-Object { $_.hwnd })
    $tracked = @(Get-TrackedHwnds $state)
    $wanted = @{}
    $alone = 0
    foreach ($w in @(Get-SavedWindows $Placement)) {
        $hwnd = [long]$w.hwnd
        # Floated, monocle, maximized or hidden to the tray since: leave it alone.
        # One that is visible, cloaked or minimized but not tracked was lost, so it
        # counts.
        if ($hwnd -notin $tiled -and ($hwnd -in $tracked -or -not (Test-WindowVisible $hwnd))) {
            $alone++
            continue
        }
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

    $now = Get-Placement (Wait-KomorebiState) $Config
    $wantVisible = @($Placement.visible) -join '|'
    if ($moved -or ($now.visible -join '|') -ne $wantVisible) {
        # The focused one last, so that it keeps the focus.
        $views = @($Placement.visible | Where-Object { $_ -ne $Placement.focused }) +
            @($Placement.focused | Where-Object { $_ })
        foreach ($name in $views) {
            komorebic focus-named-workspace $name 2>$null | Out-Null
            Start-Sleep -Milliseconds 300
        }
        $target = $wanted[[long]$Placement.window]
        if ($target -and $target -eq $Placement.focused) {
            Set-WindowForeground $Placement.window
            Start-Sleep -Milliseconds 300
        }
        $now = Get-Placement (Wait-KomorebiState) $Config
    }

    $at = @{}
    foreach ($w in $now.windows) { $at[[long]$w.hwnd] = $w.workspace }
    $right = @($wanted.Keys | Where-Object { $at[$_] -eq $wanted[$_] -and -not (Test-WindowMinimized $_) }).Count
    $note = if ($alone) { ", $alone left alone" } else { '' }
    $screens = ($now.visible -join '|') -eq $wantVisible
    if ($right -eq $wanted.Count -and $screens) {
        Write-Log "placement right: $right window(s)$note"
        return $true
    }
    Write-Log "placement wrong: $right of $($wanted.Count) window(s) in place$note, visible workspaces right: $screens"
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

# '' when everything but the placement is right, else what is wrong.
function Get-Problem {
    param($State, $Config, [bool]$BarsExpected)

    $now = @(Get-KomorebiMonitors $State $Config)
    $status = Get-Readiness $now (Get-LiveDisplays) $Config
    if ($status -ne 'ready') { return $status }
    Get-Fault $now $Config $BarsExpected
}

function Test-Healthy {
    param($State, $Config, [bool]$BarsExpected)

    -not (Get-Problem $State $Config $BarsExpected)
}

# '' once healthy, else what was still wrong when the time ran out.
function Wait-Healthy {
    param([int]$Seconds, $Config, [bool]$BarsExpected)

    $until = (Get-Date).AddSeconds($Seconds)
    $problem = 'komorebi not responding'
    do {
        Start-Sleep -Seconds 2
        try {
            $problem = Get-Problem (Get-KomorebiState) $Config $BarsExpected
            if (-not $problem) { return '' }
        } catch {
            # Busy; try again until the time is up.
            $problem = 'komorebi not responding'
        }
    } while ((Get-Date) -lt $until)
    $problem
}

# komorebi expands $Env:NAME in bar_configurations; paths are compared in full.
function Resolve-BarPath {
    param([string]$Path)

    $p = [regex]::Replace($Path, '\$Env:(\w+)', { param($m) [Environment]::GetEnvironmentVariable($m.Groups[1].Value) }, 'IgnoreCase')
    try { [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($p)) } catch { $p }
}

# Bar configs in komorebi.json with no komorebi-bar running for them. A rebuild
# starts the bars while it holds komorebi's lock, and a bar exits if its first
# request for the state is dropped (#193). Nothing if as many bars run as are
# configured, or if a running bar's config is unknown, so that a path that does
# not compare equal cannot start a second bar for one display.
function Get-MissingBars {
    param($Config)

    $wanted = @($Config.bar_configurations | Where-Object { $_ } | ForEach-Object { Resolve-BarPath $_ })
    $running = @(Get-BarProcessConfigs)
    if ($running.Count -ge $wanted.Count -or @($running | Where-Object { -not $_ }).Count) { return }
    $have = @($running | Where-Object { $_ } | ForEach-Object { Resolve-BarPath $_ })
    $wanted | Where-Object { $_ -notin $have } | Select-Object -Unique
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
                        $json = Get-Placement $state $config | ConvertTo-Json -Depth 4 -Compress
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

# Like Wait-Healthy for $RebuildSeconds, but starts a bar the rebuild lost without
# waiting for the time to run out. komorebi does not answer while it stops and
# starts the bars, so once it answers they have all been started. To be sure,
# not before $BarAfterSeconds, and two checks in a row must find the same bars
# missing. Logs the result when healthy.
function Wait-Rebuild {
    param($Config, [bool]$BarsExpected)

    $begun = Get-Date
    $until = $begun.AddSeconds($RebuildSeconds)
    $seen = ''
    $started = $false
    do {
        Start-Sleep -Seconds 2
        $missing = @()
        try {
            $problem = Get-Problem (Get-KomorebiState) $Config $BarsExpected
            if (-not $started -and $problem -eq 'bar spacing missing' -and
                (Get-Date) -ge $begun.AddSeconds($BarAfterSeconds)) {
                $missing = @(Get-MissingBars $Config)
            }
        } catch {
            # Busy; try again until the time is up.
            $problem = 'komorebi not responding'
        }
        if (-not $problem) {
            Write-Log $(if ($started) { 'after starting bar(s): labels and bar spacing right' } else { 'after rebuild: labels and bar spacing right' })
            return ''
        }
        $key = $missing -join '|'
        if ($key -and $key -eq $seen) {
            $names = @($missing | ForEach-Object { Split-Path $_ -Leaf }) -join ', '
            Write-Log "after rebuild: starting bar(s) that did not come back: $names"
            foreach ($path in $missing) {
                # Then the restart after this starts it.
                try { Start-Bar $path } catch { Write-Log "could not start $(Split-Path $path -Leaf): $($_.Exception.Message)" }
            }
            $started = $true
            $wait = (Get-Date).AddSeconds($BarSeconds)
            if ($wait -gt $until) { $until = $wait }
        }
        $seen = $key
    } while ((Get-Date) -lt $until)
    $problem
}

# Rebuilds komorebi's monitor list without restarting it, matching by serial.
# True once everything but the placement is right.
function Invoke-Rebuild {
    param([string]$Reason, $Config, [bool]$BarsExpected)

    Write-Log "rebuilding monitors: $Reason"
    komorebic replace-configuration $ConfigPath 2>$null | Out-Null
    $left = Wait-Rebuild $Config $BarsExpected
    if (-not $left) { return $true }
    if (-not (Restart-Komorebi "rebuild did not help: $Reason; still $left")) { return $false }
    $left = Wait-Healthy $RestartSeconds $Config $BarsExpected
    if (-not $left) {
        Write-Log 'after restart: labels and bar spacing right'
        return $true
    }
    Write-Log "after restart: still $left after ${RestartSeconds}s"
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
    } else {
        $problem = Get-Fault $monitors $config $barsExpected
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
        if ($placement) {
            Copy-Item -Path $placementPath -Destination $previousPath -Force
            if (-not (Restore-Placement $placement $config)) { return }
        }
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
