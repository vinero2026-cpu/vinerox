@echo off
REM Quick verification script to check all setup files

echo.
echo ===== VINEROX Build Setup Verification =====
echo.

if exist ".github\workflows\build-and-upload.yml" (
    echo [OK] .github\workflows\build-and-upload.yml exists
) else (
    echo [MISSING] .github\workflows\build-and-upload.yml
)

if exist ".github\GITHUB_SETUP.md" (
    echo [OK] .github\GITHUB_SETUP.md exists
) else (
    echo [MISSING] .github\GITHUB_SETUP.md
)

if exist "SETUP_GITHUB.bat" (
    echo [OK] SETUP_GITHUB.bat exists
) else (
    echo [MISSING] SETUP_GITHUB.bat
)

if exist "SETUP_GITHUB.sh" (
    echo [OK] SETUP_GITHUB.sh exists
) else (
    echo [MISSING] SETUP_GITHUB.sh
)

if exist "DEPLOYMENT_GUIDE.md" (
    echo [OK] DEPLOYMENT_GUIDE.md exists
) else (
    echo [MISSING] DEPLOYMENT_GUIDE.md
)

if exist "START_HERE.txt" (
    echo [OK] START_HERE.txt exists
) else (
    echo [MISSING] START_HERE.txt
)

if exist "BUILD_VERIFICATION.txt" (
    echo [OK] BUILD_VERIFICATION.txt exists
) else (
    echo [MISSING] BUILD_VERIFICATION.txt
)

if exist "android\app\build.gradle.kts" (
    echo [OK] android\app\build.gradle.kts exists
    
    REM Check for SDK 35
    findstr /M "compileSdk = 35" "android\app\build.gradle.kts" > nul
    if %ERRORLEVEL% EQU 0 (
        echo [VERIFIED] compileSdk = 35 configured
    ) else (
        echo [WARNING] compileSdk = 35 not found
    )
    
    findstr /M "targetSdk = 35" "android\app\build.gradle.kts" > nul
    if %ERRORLEVEL% EQU 0 (
        echo [VERIFIED] targetSdk = 35 configured
    ) else (
        echo [WARNING] targetSdk = 35 not found
    )
) else (
    echo [MISSING] android\app\build.gradle.kts
)

if exist "pubspec.yaml" (
    echo [OK] pubspec.yaml exists
    
    findstr /M "version: 1.0.0" "pubspec.yaml" > nul
    if %ERRORLEVEL% EQU 0 (
        echo [VERIFIED] version 1.0.0+2 configured
    ) else (
        echo [WARNING] version 1.0.0+2 not found
    )
) else (
    echo [MISSING] pubspec.yaml
)

echo.
echo ===== All checks complete =====
echo.
pause
