#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook True

; Key map
; Alt+1..6         focus named workspaces: E1 E2 E3 I1 I2 I3
; Alt+Shift+1..6   move window to:        E1 E2 E3 I1 I2 I3
; Ctrl+Alt+7       cycle previous workspace in global ring
; Ctrl+Alt+8       cycle next workspace in global ring

RunKomorebic(args) {
    exe := A_ProgramFiles . "\\komorebi\\bin\\komorebic.exe"
    Run("`"" . exe . "`" " . args, , "Hide")
}

RunWorkspace(action, slot) {
    userProfile := EnvGet("USERPROFILE")
    script := userProfile . "\\.config\\workspace-target.ps1"
    q := Chr(34)
    cmd := "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " . q . script . q . " -Action " . action . " -Slot " . slot
    Run(A_WinDir . "\\System32\\WindowsPowerShell\\v1.0\\powershell.exe " . cmd, , "Hide")
}

RunReconcile() {
    userProfile := EnvGet("USERPROFILE")
    script := userProfile . "\\.config\\workspace-reconcile.ps1"
    q := Chr(34)
    cmd := "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " . q . script . q
    Run(A_WinDir . "\\System32\\WindowsPowerShell\\v1.0\\powershell.exe " . cmd, , "Hide")
}

SetTimer(RunReconcile, 15000)
RunReconcile()

RunCycle(direction) {
    userProfile := EnvGet("USERPROFILE")
    script := userProfile . "\\.config\\workspace-ring.ps1"
    q := Chr(34)
    cmd := "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " . q . script . q . " -Direction " . direction
    Run(A_WinDir . "\\System32\\WindowsPowerShell\\v1.0\\powershell.exe " . cmd, , "Hide")
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

!+1::RunWorkspace("move", 1)
!+2::RunWorkspace("move", 2)
!+3::RunWorkspace("move", 3)
!+4::RunWorkspace("move", 4)
!+5::RunWorkspace("move", 5)
!+6::RunWorkspace("move", 6)
