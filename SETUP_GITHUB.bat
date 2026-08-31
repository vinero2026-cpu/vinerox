@echo off
REM ============================================================================
REM VINEROX GitHub Actions Setup Script
REM ============================================================================
REM This script initializes git and pushes code to GitHub for CI/CD building
REM Requirements: Git for Windows, GitHub account, personal access token
REM ============================================================================

setlocal enabledelayedexpansion

echo.
echo ===== VINEROX GitHub Actions Setup =====
echo.
echo This script will:
echo 1. Initialize a Git repository
echo 2. Configure git with your credentials
echo 3. Push to GitHub (requires token)
echo.

REM Check if git is installed
where git >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Git is not installed or not in PATH
    echo Please install Git for Windows from: https://git-scm.com/download/win
    pause
    exit /b 1
)

echo Git found: 
git --version
echo.

REM Configure git
set /p GIT_NAME="Enter Git user name (or press Enter for 'VINEROX Build'): "
if "!GIT_NAME!"=="" set GIT_NAME=VINEROX Build

set /p GIT_EMAIL="Enter Git email (or press Enter for 'build@vinerox.app'): "
if "!GIT_EMAIL!"=="" set GIT_EMAIL=build@vinerox.app

echo Configuring Git with name: !GIT_NAME!
echo Configuring Git with email: !GIT_EMAIL!
git config --global user.name "!GIT_NAME!"
git config --global user.email "!GIT_EMAIL!"

REM Initialize repository
echo.
echo Initializing Git repository...
git init
git add -A
git commit -m "VINEROX v1.0.0+2 - Target SDK 35 for Google Play 2026 compliance"
git branch -M main

echo.
echo ===== Git Initialization Complete =====
echo.
git log --oneline -1
echo.

REM GitHub remote setup
echo.
set /p GITHUB_URL="Enter your GitHub repository URL (e.g., https://github.com/YOUR_USERNAME/vinerox.git): "

if not "!GITHUB_URL!"=="" (
    echo Adding remote origin: !GITHUB_URL!
    git remote add origin !GITHUB_URL!
    echo.
    echo To push to GitHub, run:
    echo   git push -u origin main
    echo.
    echo IMPORTANT: You will be prompted for GitHub credentials.
    echo Use your personal access token (not password) if 2FA is enabled.
    echo.
    set /p DO_PUSH="Do you want to push now? (y/n): "
    if /i "!DO_PUSH!"=="y" (
        echo Pushing to GitHub...
        git push -u origin main
        echo.
        if %ERRORLEVEL% EQU 0 (
            echo ✅ Push successful!
            echo.
            echo GitHub Actions will now automatically build your app.
            echo Monitor progress at: https://github.com/YOUR_USERNAME/vinerox/actions
        ) else (
            echo ❌ Push failed. Please check your credentials and repository URL.
        )
    )
) else (
    echo No repository URL provided. Skipping remote configuration.
    echo.
    echo To add GitHub remote later, run:
    echo   git remote add origin https://github.com/YOUR_USERNAME/vinerox.git
    echo   git push -u origin main
)

echo.
echo ===== Setup Complete =====
echo.
pause
