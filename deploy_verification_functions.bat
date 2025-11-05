@echo off
REM Deploy Page Verification Cloud Functions

echo ========================================
echo  DEPLOYING PAGE VERIFICATION FUNCTIONS
echo ========================================
echo.
echo This will deploy:
echo   - approvePageVerification
echo   - rejectPageVerification
echo.
echo Press any key to continue or Ctrl+C to cancel...
pause >nul
echo.

echo [1/2] Installing dependencies...
cd functions
call npm install
if %errorlevel% neq 0 (
    echo Error: npm install failed
    cd ..
    pause
    exit /b 1
)
echo.

echo [2/2] Deploying Cloud Functions...
cd ..
call firebase deploy --only functions:approvePageVerification,functions:rejectPageVerification
if %errorlevel% neq 0 (
    echo Error: Deploy failed
    pause
    exit /b 1
)
echo.

echo ========================================
echo  DEPLOYMENT COMPLETE! ✅
echo ========================================
echo.
echo Remember to:
echo   1. Set SMTP configuration (run set_smtp_config.bat)
echo   2. Set admin users in Firestore
echo.

pause



