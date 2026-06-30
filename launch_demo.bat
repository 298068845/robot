@echo off
setlocal

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "GODOT_EXE=E:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"

if not exist "%GODOT_EXE%" (
    echo Godot executable not found:
    echo %GODOT_EXE%
    pause
    exit /b 1
)

start "" "%GODOT_EXE%" --path "%ROOT%"
endlocal

