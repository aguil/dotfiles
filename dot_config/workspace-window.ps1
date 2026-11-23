# Window and komorebi-bar process calls used by workspace-recover.ps1 (dot-sourced).
Add-Type @'
using System;
using System.Runtime.InteropServices;

[ComImport, Guid("6D5140C1-7436-11CE-8034-00AA006009FA"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IKomoServiceProvider {
    [PreserveSig] int QueryService(ref Guid service, ref Guid iid, [MarshalAs(UnmanagedType.IUnknown)] out object result);
}

// Only SetCloak is used; the placeholders keep its vtable slot.
[ComImport, Guid("372E1D3B-38D3-42E4-A15B-8AB2B178F513"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IKomoView {
    [PreserveSig] int P1(); [PreserveSig] int P2(); [PreserveSig] int P3();
    [PreserveSig] int P4(); [PreserveSig] int P5(); [PreserveSig] int P6();
    [PreserveSig] int P7(); [PreserveSig] int P8(); [PreserveSig] int P9();
    [PreserveSig] int SetCloak(uint type, int flags);
}

[ComImport, Guid("1841C6D7-4F9D-42C0-AF41-8747538F10E5"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IKomoViews {
    [PreserveSig] int P1(); [PreserveSig] int P2(); [PreserveSig] int P3();
    [PreserveSig] int GetViewForHwnd(IntPtr hwnd, out IKomoView view);
}

public static class KomoWindow {
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hwnd, int command);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr hwnd, int attr, out int value, int size);

    public static uint Pid(IntPtr hwnd) { uint pid; GetWindowThreadProcessId(hwnd, out pid); return pid; }

    public static int Cloaked(IntPtr hwnd) { int value; return DwmGetWindowAttribute(hwnd, 14, out value, 4) == 0 ? value : 0; }

    // The undocumented call komorebi's "Cloak" hiding uses: SetCloak(1, 0) shows the window.
    public static bool Uncloak(IntPtr hwnd) {
        var shell = (IKomoServiceProvider)Activator.CreateInstance(
            Type.GetTypeFromCLSID(new Guid("C2F03A33-21F5-47FA-B4BB-156362A2F239")));
        var iid = typeof(IKomoViews).GUID;
        object views;
        if (shell.QueryService(ref iid, ref iid, out views) != 0) return false;
        IKomoView view;
        if (((IKomoViews)views).GetViewForHwnd(hwnd, out view) != 0 || view == null) return false;
        return view.SetCloak(1, 0) == 0;
    }
}
'@

# Identifies a window's process, so a reused handle is not mistaken for it.
function Get-WindowOwner {
    param([long]$Hwnd)

    $id = [KomoWindow]::Pid([IntPtr]$Hwnd)
    if (-not $id) { return '' }
    $start = try { (Get-Process -Id $id -ErrorAction Stop).StartTime.Ticks } catch { 0 }
    "${id}:$start"
}

# 2 means hidden by the shell, which is how komorebi hides workspaces.
function Test-WindowCloaked {
    param([long]$Hwnd)
    [KomoWindow]::Cloaked([IntPtr]$Hwnd) -eq 2
}

function Test-WindowMinimized {
    param([long]$Hwnd)
    [KomoWindow]::IsIconic([IntPtr]$Hwnd)
}

# A cloaked window still counts as visible; one hidden to the tray does not.
function Test-WindowVisible {
    param([long]$Hwnd)
    [KomoWindow]::IsWindowVisible([IntPtr]$Hwnd)
}

# 9 is SW_RESTORE.
function Show-MinimizedWindow {
    param([long]$Hwnd)
    [void][KomoWindow]::ShowWindowAsync([IntPtr]$Hwnd, 9)
}

function Show-CloakedWindow {
    param([long]$Hwnd)
    [KomoWindow]::Uncloak([IntPtr]$Hwnd)
}

function Set-WindowForeground {
    param([long]$Hwnd)
    [void][KomoWindow]::SetForegroundWindow([IntPtr]$Hwnd)
}

function Get-WindowForeground {
    [KomoWindow]::GetForegroundWindow().ToInt64()
}

# The config path each running komorebi-bar was given, or '' for one started
# without. komorebi starts them with --config, start-komorebi.cmd with -c.
function Get-BarProcessConfigs {
    foreach ($p in Get-CimInstance -ClassName Win32_Process -Filter "Name='komorebi-bar.exe'") {
        if ("$($p.CommandLine)" -match '\s"?(?:-c|--config)"?[\s=]+(?:"([^"]+)"|(\S+))') {
            if ($Matches[1]) { $Matches[1] } else { $Matches[2] }
        } else {
            ''
        }
    }
}

function Start-Bar {
    param([string]$Path)
    $exe = (Get-Command komorebi-bar -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    Start-Process -FilePath $exe -ArgumentList '--config', "`"$Path`"" -WindowStyle Hidden | Out-Null
}
