@echo off
setlocal

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "GODOT_EXE_FROM_ENV=%GODOT_EXE%"
set "GODOT_EXE="

if exist "%ROOT%\godot_path.local.txt" (
    set /p GODOT_EXE=<"%ROOT%\godot_path.local.txt"
)

if "%GODOT_EXE%"=="" if not "%GODOT_EXE_FROM_ENV%"=="" set "GODOT_EXE=%GODOT_EXE_FROM_ENV%"

if "%GODOT_EXE%"=="" (
    for /f "delims=" %%G in ('where godot 2^>nul') do (
        set "GODOT_EXE=%%G"
        goto :found_godot
    )
)

:found_godot
if "%GODOT_EXE%"=="" (
    echo Could not find Godot.
    echo.
    echo Create a file named godot_path.local.txt next to this script.
    echo Put your Godot executable path in it, for example:
    echo D:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe
    echo.
    echo Or set GODOT_EXE, or add Godot to PATH as "godot".
    pause
    exit /b 1
)

if not exist "%GODOT_EXE%" (
    echo Godot path does not exist:
    echo %GODOT_EXE%
    echo.
    echo Please update godot_path.local.txt.
    pause
    exit /b 1
)

echo Starting demo with:
echo %GODOT_EXE%
echo.
if not exist "%ROOT%\.tmp\godot-appdata" mkdir "%ROOT%\.tmp\godot-appdata"
if not exist "%ROOT%\.tmp\godot-localappdata" mkdir "%ROOT%\.tmp\godot-localappdata"
set "APPDATA=%ROOT%\.tmp\godot-appdata"
set "LOCALAPPDATA=%ROOT%\.tmp\godot-localappdata"
start "" "%GODOT_EXE%" --path "%ROOT%"
endlocal

