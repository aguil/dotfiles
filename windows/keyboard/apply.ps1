$ErrorActionPreference = 'Stop'

$targetPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout'
$valueName = 'Scancode Map'
[byte[]]$desired = 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x02,0x00,0x00,0x00,0x1D,0x00,0x3A,0x00,0x00,0x00,0x00,0x00

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Error 'This script must be run as Administrator.'
}

$current = (Get-ItemProperty -Path $targetPath -Name $valueName -ErrorAction SilentlyContinue).$valueName

$isMatch = $false
if ($null -ne $current -and $current.Length -eq $desired.Length) {
    $isMatch = [System.Linq.Enumerable]::SequenceEqual([byte[]]$current, $desired)
}

if ($isMatch) {
    Write-Host 'Caps Lock -> Left Ctrl remap already present. No changes made.'
    Write-Host 'No reboot needed.'
    exit 0
}

New-ItemProperty -Path $targetPath -Name $valueName -PropertyType Binary -Value $desired -Force | Out-Null

Write-Host 'Applied Caps Lock -> Left Ctrl remap via Scancode Map.'
Write-Host 'Sign out or reboot is required for the remap to take effect.'
