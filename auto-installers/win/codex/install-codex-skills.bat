@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "POWERSHELL_SCRIPT=%SCRIPT_DIR%install-codex-skills.ps1"

if not exist "%POWERSHELL_SCRIPT%" (
    echo No se encontro el script de PowerShell:
    echo %POWERSHELL_SCRIPT%
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%POWERSHELL_SCRIPT%"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo.
    echo La instalacion termino con errores. Codigo de salida: %EXIT_CODE%
    pause
    exit /b %EXIT_CODE%
)

echo.
echo Instalacion completada.
pause
exit /b 0