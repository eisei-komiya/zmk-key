@echo off
chcp 65001 >nul
if "%1"=="" (
    echo Error: Please specify L or R
    echo Usage: up-firm L or up-firm R
    echo Option: Add --init for settings reset
    echo Example: up-firm R --init
    pause
    exit /b 1
)

if /i not "%1"=="L" if /i not "%1"=="R" (
    echo Error: Argument must be L or R
    pause
    exit /b 1
)

PowerShell -ExecutionPolicy Bypass -File "%~dp0up-firm.ps1" %*
pause 
