# Restores workspace names and layouts after a display change.
#
# After a reconnect, komorebi can keep a monitor with no workspaces, in the wrong
# order, without the space reserved for its bar, or as a permanent "UNKNOWN"
# display added before Windows gave it an ID. Windows can also be left unmanaged.
# This waits for Windows and komorebi to settle, then rebuilds komorebi's monitor
# list in place, which also adopts the windows and restarts the bars. Reloading
# komorebi.json is not enough: it only reapplies names and layouts. komorebi is
# restarted only if the rebuild fails. Monitors are never identified by position.
# Does nothing when everything is already right.
param(
    [string]$ConfigPath = (Join-Path $env:USERPROFILE 'komorebi.json'),
    [string]$StartScript = (Join-Path $env:USERPROFILE '.config\start-komorebi.cmd'),
    [string]$DataDir = (Join-Path $env:LOCALAPPDATA 'komorebi'),
    [int]$TimeoutSeconds = 20,
    [int]$PollSeconds = 3,
    [int]$RebuildSeconds = 20,
    [int]$RestartCooldownMinutes = 10
)

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

# Monitors komorebi knows, in its order, with the config index each one matches.
function Get-KomorebiMonitors {
    param($Config)

    # komorebic fails while komorebi is busy; the caller polls again.
    $state = komorebic state 2>$null | ConvertFrom-Json
    foreach ($m in $state.monitors.elements) {
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

function Restart-Komorebi {
    param([string]$Reason)

    $stamp = Join-Path $DataDir 'workspace-recover.restart'
    if ((Test-Path $stamp) -and
        (Get-Item $stamp).LastWriteTime -gt (Get-Date).AddMinutes(-$RestartCooldownMinutes)) {
        Write-Log "restart skipped, cooling down: $Reason"
        return
    }
    Set-Content -Path $stamp -Value $Reason
    Write-Log "restarting komorebi: $Reason"
    Start-Process -FilePath $env:ComSpec -ArgumentList "/c `"$StartScript`"" -WindowStyle Hidden
}

# Rebuilds komorebi's monitor list without restarting it, matching by serial.
function Invoke-Rebuild {
    param([string]$Reason, $Config, [bool]$BarsExpected)

    Write-Log "rebuilding monitors: $Reason"
    komorebic replace-configuration $ConfigPath 2>$null | Out-Null
    $until = (Get-Date).AddSeconds($RebuildSeconds)
    do {
        Start-Sleep -Seconds 2
        try {
            $now = @(Get-KomorebiMonitors $Config)
            if ((Get-Readiness $now (Get-LiveDisplays) $Config) -eq 'ready' -and
                (Test-Order $now) -and (Test-Labels $now $Config) -and
                (Test-Spacing $now $Config $BarsExpected)) {
                Write-Log 'after rebuild: labels and bar spacing right'
                return
            }
        } catch {
            # Busy rebuilding; try again until the time is up.
        }
    } while ((Get-Date) -lt $until)
    Restart-Komorebi "rebuild did not help: $Reason"
}

$mutex = New-Object System.Threading.Mutex($false, 'Local\komorebi-workspace-recover')
$owned = $false
try {
    try { $owned = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $owned = $true }
    if (-not $owned) { return }

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
            $monitors = @(Get-KomorebiMonitors $config)
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

    if ($status -in 'serial missing', 'configured display missing') {
        Invoke-Rebuild $status $config $barsExpected
    } elseif ($status -ne 'ready') {
        Write-Log "gave up after ${TimeoutSeconds}s: $status"
    } elseif (-not (Test-Order $monitors)) {
        Invoke-Rebuild 'monitors out of order' $config $barsExpected
    } elseif (-not (Test-Labels $monitors $config)) {
        Invoke-Rebuild 'labels wrong' $config $barsExpected
    } elseif (-not (Test-Spacing $monitors $config $barsExpected)) {
        Invoke-Rebuild 'bar spacing missing' $config $barsExpected
    }
} catch {
    Write-Log "error: $($_.Exception.Message)"
} finally {
    if ($owned) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
