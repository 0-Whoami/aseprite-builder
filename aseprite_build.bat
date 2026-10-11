@echo off
setlocal enabledelayedexpansion

:: =================================================================
:: Aseprite Builder - Windows Batch Script
:: Automated build script for Aseprite (GitHub Actions compatible)
:: =================================================================

:: =================================================================
:: 1. CONFIGURATION
:: =================================================================
set "ROOT_DIR=%~dp0workspace"
set "ASEPRITE_DIR=%ROOT_DIR%\aseprite"
set "BUILD_DIR=%ROOT_DIR%\build"
set "SKIA_DIR=%ROOT_DIR%\skia"
set "INSTALLER_DIR=%ROOT_DIR%\installer"
set "SKIA_ZIP=%ROOT_DIR%\Skia-Windows-Release-x64.zip"
set "ISS_FILE=%ROOT_DIR%\aseprite_installer.iss"

echo =================================================================
echo Aseprite Builder - Automated Build Process
echo =================================================================
echo.

:: =================================================================
:: 2. PRE-FLIGHT CHECKS
:: =================================================================
echo [1/6] Running pre-flight checks...
if not exist "%ROOT_DIR%" mkdir "%ROOT_DIR%" 2>nul

:: Check for required tools (don't exit, just warn)
where cmake >nul 2>nul || echo [!] WARNING: CMake not found in PATH
where ninja >nul 2>nul || echo [!] WARNING: Ninja not found in PATH

:: Locate Visual Studio (more robust detection)
set "VS_INSTALL_DIR="
for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -requires Microsoft.Component.MSBuild -property installationPath 2^>nul`) do (
    set "VS_INSTALL_DIR=%%i"
)

if not defined VS_INSTALL_DIR (
    echo [!] WARNING: Visual Studio not detected via vswhere
    echo [!] Continuing - may work in CI with msvc-dev-cmd
)

:: =================================================================
:: 3. FETCH VERSION & DYNAMIC DOWNLOAD URL
:: =================================================================
echo [2/6] Fetching latest release metadata...

:: Detect if running in CI
if defined GITHUB_ACTIONS (
    echo [+] GitHub Actions detected - using environment variables
) else (
    echo [+] Local build detected
)

:: PowerShell command to get release info with better error handling
set "PS_CMD=$ErrorActionPreference='Stop'; try { $r=(Invoke-WebRequest -UseBasicParsing https://api.github.com/repos/aseprite/aseprite/releases/latest).Content|ConvertFrom-Json; $u=$r.assets|Where-Object {$_.name -like '*Source.zip'}|Select-Object -ExpandProperty browser_download_url; $v=$r.tag_name; Write-Output \"$u|$v\" } catch { Write-Output '|' }"

for /f "tokens=1,2 delims=|" %%a in ('powershell -Command "%PS_CMD%" 2^>nul') do (
    set "DOWNLOAD_URL=%%a"
    set "ASE_VER=%%b"
)

if "%DOWNLOAD_URL%"=="" (
    echo [!] Could not fetch latest release from GitHub API
    echo [!] Using fallback: v1.3.17
    set "ASE_VER=v1.3.17"
    set "DOWNLOAD_URL=https://github.com/aseprite/aseprite/releases/download/v1.3.17/Aseprite-v1.3.17-Source.zip"
)

echo [+] Detected Version: %ASE_VER%
echo [+] Asset URL: %DOWNLOAD_URL%
echo.

:: =================================================================
:: 4. CLEANING & DOWNLOADING
:: =================================================================
echo [3/6] Cleaning and downloading...
rd /s /q "%ASEPRITE_DIR%" 2>nul
rd /s /q "%BUILD_DIR%" 2>nul
mkdir "%BUILD_DIR%" "%INSTALLER_DIR%" "%ASEPRITE_DIR%" 2>nul

:: Download Aseprite Source
set "ASE_ZIP=%ROOT_DIR%\aseprite_src.zip"
echo Downloading Aseprite source...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%ASE_ZIP%' -UseBasicParsing; Write-Output 'Download successful' } catch { Write-Error $_.Exception.Message; exit 1 }" || (
    echo [!] CRITICAL: Failed to download Aseprite source
    echo Check your internet connection and the URL
    exit /b 1
)

:: Extract using PowerShell (no 7z dependency)
echo Extracting Aseprite source...
set "TEMP_EXTRACT=%ROOT_DIR%\temp_ext"
mkdir "%TEMP_EXTRACT%" 2>nul
powershell -Command "Expand-Archive -Force '%ASE_ZIP%' '%TEMP_EXTRACT%'" || (
    echo [!] CRITICAL: Failed to extract Aseprite source
    exit /b 1
)

for /d %%f in ("%TEMP_EXTRACT%\*") do xcopy /e /y /q "%%f\*" "%ASEPRITE_DIR%\" >nul
rd /s /q "%TEMP_EXTRACT%" 2>nul
del /f /q "%ASE_ZIP%" 2>nul
echo [+] Aseprite source extracted

:: Download Skia
if not exist "%SKIA_ZIP%" (
    echo Downloading Skia library...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/aseprite/skia/releases/download/m102-861e4743af/Skia-Windows-Release-x64.zip' -OutFile '%SKIA_ZIP%' -UseBasicParsing" || (
        echo [!] WARNING: Failed to download Skia
    )
)

if exist "%SKIA_ZIP%" (
    echo Extracting Skia...
    powershell -Command "Expand-Archive -Force '%SKIA_ZIP%' '%SKIA_DIR%'"
    echo [+] Skia extracted
) else (
    echo [!] WARNING: Skia not available - build may fail
)
