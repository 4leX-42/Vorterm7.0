@echo off
setlocal ENABLEDELAYEDEXPANSION
chcp 65001 >nul
title PowerShell Terminal Setup - Launcher

REM -------------------------------------------------------
REM  PowerShell Terminal Setup - Lanzador
REM  Doble clic. Auto-eleva. Auto-instala. Auto-configura.
REM -------------------------------------------------------

:: --- 1. Comprobar privilegios de administrador --------------
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo.
    echo  [!] Se requieren permisos de administrador.
    echo  [>] Relanzando elevado...
    echo.
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: --- 2. Elegir el mejor host de PowerShell disponible -------
set "PS_EXE="
where pwsh >nul 2>&1
if %errorlevel%==0 (
    set "PS_EXE=pwsh"
    set "PS_ARGS=-NoLogo -NoProfileLoadTime -ExecutionPolicy Bypass -File"
) else (
    set "PS_EXE=powershell"
    set "PS_ARGS=-NoLogo -ExecutionPolicy Bypass -File"
)

echo  [i] Host: %PS_EXE%
echo  [i] Script: %~dp0setup_terminal.ps1
echo.

:: --- 3. Ejecutar el script principal ------------------------
%PS_EXE% %PS_ARGS% "%~dp0setup_terminal.ps1"
set "RC=%errorlevel%"

echo.
if %RC% NEQ 0 (
    echo  [X] Setup terminado con errores (code %RC%).
) else (
    echo  [OK] Setup finalizado correctamente.
)
echo.
pause
endlocal
exit /b %RC%
