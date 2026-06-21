@echo off
setlocal

set "LOG=%LOCALAPPDATA%\komorebi\startup.cmd.log"
echo %date% %time% Startup CMD begin>>"%LOG%"

echo %date% %time% Stopping existing processes>>"%LOG%"
powershell -NoProfile -Command "& { try { komorebic stop } catch {} }" >nul 2>&1
powershell -NoProfile -Command "Start-Sleep -Seconds 2" >nul 2>&1
taskkill /F /IM komorebi.exe >nul 2>&1
taskkill /F /IM komorebi-bar.exe >nul 2>&1
taskkill /F /IM whkd.exe >nul 2>&1
taskkill /F /IM AutoHotkey64.exe >nul 2>&1
powershell -NoProfile -Command "Start-Sleep -Seconds 2" >nul 2>&1

set "KOMOREBI_OK=0"
for /L %%A in (1,1,8) do (
  echo %date% %time% Attempt %%A starting komorebi.exe>>"%LOG%"
  powershell -NoProfile -Command "Start-Process -FilePath 'C:\Program Files\komorebi\bin\komorebi.exe' -WindowStyle Hidden" >nul 2>&1
  powershell -NoProfile -Command "Start-Sleep -Seconds 20" >nul 2>&1

  tasklist /FI "IMAGENAME eq komorebi.exe" | find /I "komorebi.exe" >nul
  if not errorlevel 1 (
    set "KOMOREBI_OK=1"
    echo %date% %time% komorebi.exe started on attempt %%A>>"%LOG%"
    goto :after_komorebi
  )
)

:after_komorebi
if "%KOMOREBI_OK%"=="0" (
  echo %date% %time% komorebi.exe not detected after retries>>"%LOG%"
)

powershell -NoProfile -Command "Start-Sleep -Seconds 4" >nul 2>&1

echo %date% %time% Starting bars>>"%LOG%"
powershell -NoProfile -Command "Start-Process -FilePath 'C:\Program Files\komorebi\bin\komorebi-bar.exe' -ArgumentList '-c \"%USERPROFILE%\komorebi.bar.0.json\"' -WindowStyle Hidden" >nul 2>&1
powershell -NoProfile -Command "Start-Process -FilePath 'C:\Program Files\komorebi\bin\komorebi-bar.exe' -ArgumentList '-c \"%USERPROFILE%\komorebi.bar.1.json\"' -WindowStyle Hidden" >nul 2>&1
powershell -NoProfile -Command "Start-Process -FilePath 'C:\Program Files\komorebi\bin\komorebi-bar.exe' -ArgumentList '-c \"%USERPROFILE%\komorebi.bar.2.json\"' -WindowStyle Hidden" >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\jason\.config\workspace-reconcile.ps1" >nul 2>&1
echo %date% %time% Reconciled workspace names>>"%LOG%"

echo %date% %time% Starting whkd.exe>>"%LOG%"
powershell -NoProfile -Command "Start-Process -FilePath 'C:\Program Files\whkd\bin\whkd.exe' -WindowStyle Hidden" >nul 2>&1

echo %date% %time% Starting workspace-cycle.ahk>>"%LOG%"
powershell -NoProfile -Command "Start-Process -FilePath 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' -ArgumentList '\"C:\Users\jason\.config\workspace-cycle.ahk\"' -WindowStyle Hidden" >nul 2>&1

echo %date% %time% Startup CMD end>>"%LOG%"
endlocal
