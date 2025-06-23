@echo off
REM DeepMimic Windows Setup Batch Script
REM This batch file calls the PowerShell setup script

echo DeepMimic Windows Setup
echo.

REM Check if PowerShell is available
powershell -Command "Get-Host" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo PowerShell is required but not found. Please install PowerShell.
    pause
    exit /b 1
)

REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0

REM Check if setup.ps1 exists
if not exist "%SCRIPT_DIR%setup.ps1" (
    echo setup.ps1 not found in the same directory as this batch file.
    pause
    exit /b 1
)

echo Running PowerShell setup script...
echo.

REM Execute the PowerShell script with execution policy bypass
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup.ps1"

if %ERRORLEVEL% neq 0 (
    echo Setup failed. Please check the error messages above.
    pause
    exit /b 1
)

echo.
echo Setup completed successfully!
echo.
echo To get started:
echo 1. Open PowerShell in this directory
echo 2. Activate the Python environment: .\py\Scripts\Activate.ps1
echo 3. Run DeepMimic: python DeepMimic.py --arg_file args\run_humanoid3d_spinkick_args.txt
echo.
pause 