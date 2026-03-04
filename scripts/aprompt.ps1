[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Name,

    [switch]$Copy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$legacyPath = Join-Path $scriptDir "oprompt.ps1"

if (-not (Test-Path -LiteralPath $legacyPath)) {
    throw "Prompt helper not found: $legacyPath"
}

& $legacyPath -Name $Name -Copy:$Copy
