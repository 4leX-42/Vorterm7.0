@echo off
:: ============================================================
::  Vorterm 7.2
::  Doble click. Eso es todo.
:: ============================================================

:: WPF needs STA. powershell.exe (5.1) ships in every Windows
:: and supports WPF/STA natively. Hidden so only the GUI shows.
:: -ExecutionPolicy Bypass applies to this process only; the
:: installer sets CurrentUser to RemoteSigned for new terminals.
start "" powershell.exe -NoLogo -NoProfile -STA -WindowStyle Hidden ^
    -ExecutionPolicy Bypass -File "%~dp0setup_terminal.ps1"
