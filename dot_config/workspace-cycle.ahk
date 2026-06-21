#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook True

; Key map
; Alt+1..9         focus named workspaces: I1 I2 I3 E4 E5 E6 E7 E8 E9 (adaptive)
; Alt+Shift+1..9   move window to:        I1 I2 I3 E4 E5 E6 E7 E8 E9 (adaptive)
; Ctrl+Alt+7       cycle previous workspace in global ring
; Ctrl+Alt+8       cycle next workspace in global ring

RunKomorebic(args) {
    exe := A_ProgramFiles . "\\komorebi\\bin\\komorebic.exe"
    Run("`"" . exe . "`" " . args, , "Hide")
}

GetPowerShellExe() {
    pwshExe := A_ProgramFiles . "\\PowerShell\\7\\pwsh.exe"
    if FileExist(pwshExe) {
        return pwshExe
    }

    return A_WinDir . "\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
}

RunWorkspace(action, slot) {
    userProfile := EnvGet("USERPROFILE")
    script := userProfile . "\\.config\\workspace-target.ps1"
    q := Chr(34)
    cmd := "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " . q . script . q . " -Action " . action . " -Slot " . slot
    Run(GetPowerShellExe() . " " . cmd, , "Hide")
}

RunReconcile() {
    userProfile := EnvGet("USERPROFILE")
    script := userProfile . "\\.config\\workspace-reconcile.ps1"
    q := Chr(34)
    cmd := "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " . q . script . q
    Run(GetPowerShellExe() . " " . cmd, , "Hide")
}

SetTimer(RunReconcile, 15000)
RunReconcile()

RunCycle(direction) {
    userProfile := EnvGet("USERPROFILE")
    script := userProfile . "\\.config\\workspace-ring.ps1"
    q := Chr(34)
    cmd := "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " . q . script . q . " -Direction " . direction
    Run(GetPowerShellExe() . " " . cmd, , "Hide")
}

#F7::RunCycle("previous")
#F8::RunCycle("next")
^!7::RunCycle("previous")
^!8::RunCycle("next")

!1::RunWorkspace("focus", 1)
!2::RunWorkspace("focus", 2)
!3::RunWorkspace("focus", 3)
!4::RunWorkspace("focus", 4)
!5::RunWorkspace("focus", 5)
!6::RunWorkspace("focus", 6)
!7::RunWorkspace("focus", 7)
!8::RunWorkspace("focus", 8)
!9::RunWorkspace("focus", 9)

!+1::RunWorkspace("move", 1)
!+2::RunWorkspace("move", 2)
!+3::RunWorkspace("move", 3)
!+4::RunWorkspace("move", 4)
!+5::RunWorkspace("move", 5)
!+6::RunWorkspace("move", 6)
!+7::RunWorkspace("move", 7)
!+8::RunWorkspace("move", 8)
!+9::RunWorkspace("move", 9)
