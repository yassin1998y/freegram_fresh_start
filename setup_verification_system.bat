@echo off
REM Complete setup script for Page Verification System
REM This script will guide you through setting up:
REM   1. SMTP configuration
REM   2. Deploying Cloud Functions
REM   3. Setting admin users

echo ========================================
echo  PAGE VERIFICATION SYSTEM SETUP
echo ========================================
echo.
echo This script will help you set up:
echo   1. SMTP Email Configuration (optional)
echo   2. Deploy Cloud Functions
echo   3. Set Admin Users (manual - instructions provided)
echo.
pause

echo.
echo ========================================
echo  STEP 1: SMTP Configuration (Optional)
echo ========================================
echo.
echo Do you want to configure SMTP now? (Y/N)
set /p CONFIGURE_SMTP="> "
if /i "%CONFIGURE_SMTP%"=="Y" (
    echo.
    echo Please edit set_smtp_config.bat and run it manually
    echo OR set environment variables in Firebase Console:
    echo   Functions → Configuration → Environment Variables
    echo.
    echo Required variables:
    echo   - SMTP_HOST (e.g., smtp.gmail.com)
    echo   - SMTP_PORT (e.g., 587)
    echo   - SMTP_USER (your email)
    echo   - SMTP_PASSWORD (your app password)
    echo   - SMTP_FROM (sender email)
    echo.
    pause
) else (
    echo Skipping SMTP configuration.
    echo You can set it later via Firebase Console.
)

echo.
echo ========================================
echo  STEP 2: Deploy Cloud Functions
echo ========================================
echo.
echo Installing dependencies...
cd functions
call npm install
if %errorlevel% neq 0 (
    echo Error: npm install failed
    cd ..
    pause
    exit /b 1
)
cd ..

echo.
echo Deploying verification functions...
call firebase deploy --only functions
if %errorlevel% neq 0 (
    echo Warning: Deployment may have failed or functions need secrets
    echo Check the output above for details
)

echo.
echo ========================================
echo  STEP 3: Set Admin Users
echo ========================================
echo.
echo To set an admin user, you have two options:
echo.
echo Option 1: Firebase Console (Easiest)
echo   1. Go to: https://console.firebase.google.com/project/prototype-29c26/firestore
echo   2. Navigate to: users collection
echo   3. Open the user document you want to make admin
echo   4. Add field: role = "admin" (string) OR isAdmin = true (boolean)
echo.
echo Option 2: Using this script
echo   Run: set_admin_user.bat (edit it first with user ID)
echo.
pause

echo.
echo ========================================
echo  SETUP COMPLETE!
echo ========================================
echo.
echo Next steps:
echo   1. Set admin users in Firestore (see instructions above)
echo   2. (Optional) Configure SMTP for email notifications
echo   3. Test verification flow:
echo      - Create a page
echo      - Request verification
echo      - Approve/reject as admin
echo.
pause



