@echo off
REM Deploy FCM Cloud Function with Grouped Messages Support
REM This script deploys the updated FCM notification functions

echo ========================================
echo  Deploying FCM Grouped Messages Update
echo ========================================
echo.

cd functions

echo [1/3] Installing dependencies...
call npm install
if %errorlevel% neq 0 (
    echo Error: npm install failed
    pause
    exit /b 1
)
echo.

echo [2/3] Deploying Cloud Functions...
echo.
echo Deploying: sendMessageNotification (with message grouping)
call firebase deploy --only functions:sendMessageNotification
if %errorlevel% neq 0 (
    echo Error: Deploy failed for sendMessageNotification
    pause
    exit /b 1
)
echo.

echo [3/3] Verification...
call firebase functions:log --only sendMessageNotification --limit 5
echo.

cd ..

echo ========================================
echo  Deployment Complete!
echo ========================================
echo.
echo What's New:
echo  ✓ Messages are now grouped (shows last 10 messages)
echo  ✓ WhatsApp-style MessagingStyle notifications
echo  ✓ Action buttons: Reply and Mark as Read
echo  ✓ Professional message formatting
echo.
echo Next Steps:
echo  1. Send a test message to verify grouped notifications
echo  2. Check notification shows conversation history
echo  3. Test action buttons (Reply, Mark as Read)
echo.
pause

