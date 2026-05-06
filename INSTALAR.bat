@echo off
:: ============================================================
::  TERMIX  v3.1  -  professional terminal installer
::  Doble click. Eso es todo.
:: ============================================================

:: WPF needs STA. powershell.exe (5.1) ships in every Windows
:: and supports WPF/STA natively. Hidden so only the GUI shows.
start "" powershell.exe -NoLogo -NoProfile -STA -WindowStyle Hidden ^
    -ExecutionPolicy Bypass -File "%~dp0setup_terminal.ps1"
