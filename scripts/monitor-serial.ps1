# Prints the serial number of a monitor model as komorebi reports it, or nothing
# when it is unknown or ambiguous. Called by .chezmoi.toml.tmpl during
# `chezmoi init`, so it must always exit 0.
#
# Reads the EDID Windows keeps for every monitor it has seen, so the monitor does
# not need to be connected and no elevation is needed.
param(
    # PnP model code, for example VSCC336.
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9]+$')]
    [string]$Model,

    [string]$Root = 'HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY'
)

function Get-EdidSerial {
    param([byte[]]$Edid)

    if (-not $Edid -or $Edid.Length -lt 128) {
        return
    }

    # Prefer the serial text descriptor (type 0xFF).
    foreach ($offset in 54, 72, 90, 108) {
        if ($Edid[$offset] -eq 0 -and $Edid[$offset + 1] -eq 0 -and
            $Edid[$offset + 2] -eq 0 -and $Edid[$offset + 3] -eq 0xFF) {
            $text = [Text.Encoding]::ASCII.GetString($Edid, $offset + 5, 13)
            $text = $text.Split("`n")[0].Trim([char]0, ' ', "`r")
            if ($text) {
                return $text
            }
        }
    }

    # Otherwise use the numeric serial, unless it is a known placeholder.
    $number = [BitConverter]::ToUInt32($Edid, 12)
    if ($number -ne 0 -and $number -ne 0x01010101) {
        return "$number"
    }
}

try {
    $serials = @(
        Get-ChildItem -Path (Join-Path $Root $Model) -ErrorAction Stop | ForEach-Object {
            $parameters = Join-Path $_.PSPath 'Device Parameters'
            Get-EdidSerial (Get-ItemProperty -Path $parameters -Name EDID -ErrorAction SilentlyContinue).EDID
        } | Where-Object { $_ -match '^[A-Za-z0-9._-]+$' } | Sort-Object -Unique
    )

    # Two different serials means two units of the model; do not guess.
    if ($serials.Count -eq 1) {
        [Console]::Out.Write($serials[0])
    }
} catch {
    # Model never connected, or the registry is unreadable: leave it blank.
}

exit 0
