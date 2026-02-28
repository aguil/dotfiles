[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Name,

    [switch]$Copy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$promptPath = Join-Path $repoRoot "docs\prompts\$Name.md"

if (-not (Test-Path -LiteralPath $promptPath)) {
    throw "Prompt not found: $promptPath"
}

$content = Get-Content -LiteralPath $promptPath -Raw

if ($Copy) {
    Set-Clipboard -Value $content
    Write-Host "Copied prompt '$Name' to clipboard."
} else {
    Write-Output $content
}
