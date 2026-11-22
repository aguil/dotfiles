# Restores workspace names and layouts after a display change.
#
# komorebi looks up a reconnected monitor's workspaces once, when it adds the
# monitor. Its serial may not be available yet; then the lookup misses and the
# monitor keeps one unnamed workspace. This waits for the serials, then makes
# komorebi reload komorebi.json, which matches by serial. Monitors are never
# identified by position. Does nothing when the labels are already right.
param(
    [string]$ConfigPath = (Join-Path $env:USERPROFILE 'komorebi.json'),
    [string]$StartScript = (Join-Path $env:USERPROFILE '.config\start-komorebi.cmd'),
    [string]$DataDir = (Join-Path $env:LOCALAPPDATA 'komorebi'),
    [int]$TimeoutSeconds = 45,
    [int]$PollSeconds = 3,
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

    $state = komorebic state | ConvertFrom-Json
    foreach ($m in $state.monitors.elements) {
        $match = $Config.display_index_preferences.PSObject.Properties | Where-Object {
            $_.Value -eq $m.device_id -or ($m.serial_number_id -and $_.Value -eq $m.serial_number_id)
        } | Select-Object -First 1
        [PSCustomObject]@{
            DeviceId = $m.device_id
            Serial   = $m.serial_number_id
            Index    = if ($match) { [int]$match.Name } else { $null }
            Names    = @($m.workspaces.elements | ForEach-Object { "$($_.name)" })
        }
    }
}

# 'ready', or why komorebi's view does not match Windows yet.
function Get-Readiness {
    param($Monitors, $Live)

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

$mutex = New-Object System.Threading.Mutex($false, 'Local\komorebi-workspace-recover')
$owned = $false
try {
    try { $owned = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $owned = $true }
    if (-not $owned) { return }

    $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $previous = ''
    $status = 'no data'

    # Act only once two polls in a row agree that komorebi has caught up.
    while ($true) {
        try {
            $live = Get-LiveDisplays
            $monitors = @(Get-KomorebiMonitors $config)
            $status = Get-Readiness $monitors $live
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

    if ($status -eq 'serial missing') {
        # A reload cannot match a monitor whose serial komorebi never picked up.
        Restart-Komorebi 'komorebi has no serial for a connected monitor'
    } elseif ($status -ne 'ready') {
        Write-Log "gave up after ${TimeoutSeconds}s: $status"
    } elseif (-not (Test-Order $monitors)) {
        Restart-Komorebi 'monitors are out of order'
    } elseif (-not (Test-Labels $monitors $config)) {
        Write-Log 'labels wrong, reloading komorebi.json'
        (Get-Item $ConfigPath).LastWriteTime = Get-Date
        Start-Sleep -Seconds ($PollSeconds * 2)
        $ok = Test-Labels @(Get-KomorebiMonitors $config) $config
        Write-Log "after reload: labels $(if ($ok) { 'right' } else { 'still wrong' })"
    }
} catch {
    Write-Log "error: $($_.Exception.Message)"
} finally {
    if ($owned) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
