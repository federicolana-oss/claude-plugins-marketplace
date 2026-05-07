@echo off
REM Wrapper para health_check.py — corre 30 min después de refresh.
REM Schedule:
REM   $a = New-ScheduledTaskAction -Execute "C:\ruta\health_check.bat"
REM   $t = New-ScheduledTaskTrigger -Daily -At 8:30am
REM   Register-ScheduledTask -TaskName "OPPnL-HealthCheck" -Action $a -Trigger $t

cd /d "%~dp0"
python health_check.py
exit /b %errorlevel%
