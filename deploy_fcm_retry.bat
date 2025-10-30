@echo off
REM Deploy FCM Cloud Functions - With Auto-Retry for First-Time Setup
echo ========================================
echo   FCM Deployment with Auto-Retry
echo ========================================
echo.
echo This script handles first-time 2nd Gen function setup.
echo It will automatically retry after waiting for permissions.
echo.

REM First attempt
echo [Attempt 1/2] Deploying functions...
echo.
cd functions
call npm install
if %errorlevel% neq 0 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b %errorlevel%
)
cd ..

call firebase deploy --only functions --project prototype-29c26
if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo   ✅ Deployment Successful!
    echo ========================================
    echo.
    echo Your Cloud Functions are now live!
    echo Test endpoint: https://us-central1-prototype-29c26.cloudfunctions.net/test
    echo.
    pause
    exit /b 0
)

echo.
echo ⏳ First deployment encountered setup delay...
echo    This is normal for first-time 2nd Gen functions.
echo.
echo 📝 Google Cloud is setting up:
echo    - Eventarc service permissions
echo    - Service identities
echo    - API connections
echo.
echo ⏱️  Waiting 3 minutes for setup to complete...
echo.

REM Countdown timer
for /L %%i in (180,-1,1) do (
    set /a minutes=%%i/60
    set /a seconds=%%i%%60
    <nul set /p =Waiting: !minutes!:!seconds! remaining...
    timeout /t 1 /nobreak >nul
    <nul set /p =
)

echo.
echo.
echo ========================================
echo   [Attempt 2/2] Retrying deployment...
echo ========================================
echo.

call firebase deploy --only functions --project prototype-29c26
if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo   ✅ Deployment Successful!
    echo ========================================
    echo.
    echo Your Cloud Functions are now live!
    echo Test endpoint: https://us-central1-prototype-29c26.cloudfunctions.net/test
    echo.
    pause
    exit /b 0
) else (
    echo.
    echo ========================================
    echo   ⚠️ Still Having Issues
    echo ========================================
    echo.
    echo The setup might need a bit more time.
    echo.
    echo What to do:
    echo 1. Wait another 5 minutes
    echo 2. Then run: firebase deploy --only functions
    echo.
    echo Or check: FIRST_TIME_SETUP_WAIT.md
    echo.
    pause
    exit /b %errorlevel%
)

