@echo off
if "%1"=="" (
    echo エラー: 引数LまたはRを指定してください
    echo 使い方: up-firm L または up-firm R
    echo オプション: --init を追加すると設定リセットも実行
    echo 例: up-firm R --init
    pause
    exit /b 1
)

if /i not "%1"=="L" if /i not "%1"=="R" (
    echo エラー: 引数はLまたはRを指定してください
    pause
    exit /b 1
)

PowerShell -ExecutionPolicy Bypass -File "%~dp0up-firm.ps1" %*
pause 