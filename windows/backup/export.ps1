[CmdletBinding()]
param(
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Copy-IfExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Host "skip  $Source"
        return
    }

    $parent = Split-Path -Path $Destination -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    Write-Host "copy  $Source -> $Destination"
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Join-Path $PSScriptRoot "..\.."
}

$repoRootPath = (Resolve-Path -LiteralPath $RepoRoot).Path

$targets = @(
    @{
        Source = Join-Path $HOME "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
        Destination = Join-Path $repoRootPath "home\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
    },
    @{
        Source = Join-Path $HOME "Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        Destination = Join-Path $repoRootPath "home\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    },
    @{
        Source = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        Destination = Join-Path $repoRootPath "windows\terminal\settings.json"
    },
    @{
        Source = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
        Destination = Join-Path $repoRootPath "windows\terminal\settings.preview.json"
    },
    @{
        Source = Join-Path $env:APPDATA "Code\User\settings.json"
        Destination = Join-Path $repoRootPath "windows\vscode\settings.json"
    },
    @{
        Source = Join-Path $env:APPDATA "Code\User\keybindings.json"
        Destination = Join-Path $repoRootPath "windows\vscode\keybindings.json"
    }
)

Write-Host "Repo root: $repoRootPath"

foreach ($target in $targets) {
    Copy-IfExists -Source $target.Source -Destination $target.Destination
}

$wingetOutput = Join-Path $repoRootPath "windows\backup\winget-packages.json"

if (Get-Command winget -ErrorAction SilentlyContinue) {
    $wingetParent = Split-Path -Path $wingetOutput -Parent
    if (-not (Test-Path -LiteralPath $wingetParent)) {
        New-Item -ItemType Directory -Path $wingetParent -Force | Out-Null
    }

    winget export --output $wingetOutput --accept-source-agreements | Out-Null
    Write-Host "export winget -> $wingetOutput"
} else {
    Write-Host "skip  winget export (winget not found)"
}

Write-Host "Done."
