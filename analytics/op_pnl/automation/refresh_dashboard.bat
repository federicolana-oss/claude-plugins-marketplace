@echo off
REM ==============================================================
REM refresh_dashboard.bat
REM Orquesta:  git pull -> upload Grid -> propaga exit codes
REM
REM Pre-requisitos:
REM   - VPN MELI activa
REM   - Python 3.11+ en PATH
REM   - pip install requests python-dotenv
REM   - .env configurado (ver .env.example)
REM
REM Uso manual:
REM   refresh_dashboard.bat
REM
REM Schedule (PowerShell, daily 08:00):
REM   $a = New-ScheduledTaskAction -Execute "C:\ruta\refresh_dashboard.bat"
REM   $t = New-ScheduledTaskTrigger -Daily -At 8am
REM   $s = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries
REM   Register-ScheduledTask -TaskName "OPPnL-Refresh" -Action $a -Trigger $t -Settings $s
REM ==============================================================

setlocal enabledelayedexpansion

REM Cambiar a la carpeta del script
cd /d "%~dp0"

set LOG_DIR=%~dp0logs
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set TS=%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%
set LOG=%LOG_DIR%\refresh_!TS: =0!.log

echo [%date% %time%] Starting refresh > "%LOG%"

REM === 1. Pull latest from git ===
echo [step 1/2] git pull >> "%LOG%"
cd ..\..\..
git pull --rebase >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [ERROR] git pull failed >> "%LOG%"
    type "%LOG%"
    exit /b 1
)
cd "%~dp0"

REM === 2. Upload latest HTML to Grid ===
echo [step 2/2] uploading to Grid >> "%LOG%"
python grid_upload.py >> "%LOG%" 2>&1
if errorlevel 1 (
    echo [ERROR] grid_upload failed >> "%LOG%"
    type "%LOG%"
    exit /b 2
)

echo [%date% %time%] DONE >> "%LOG%"
type "%LOG%"
exit /b 0
