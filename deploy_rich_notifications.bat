@echo off
echo.
echo ========================================
echo   DEPLOY: Rich Grouped Notifications
echo ========================================
echo.
echo This will deploy:
echo  1. Cloud Functions with photo URLs in data payload
echo  2. Background notification handler with ProfessionalNotificationManager
echo.
echo Features:
echo  ✅ WhatsApp-style message grouping (InboxStyle)
echo  ✅ Show multiple messages in one notification
echo  ✅ Profile pictures (circular, not huge!)
echo  ✅ Proper notification updates (not separate ones)
echo.
pause

cd functions

echo.
echo [1/2] Installing dependencies...
call npm install
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: npm install failed
    pause
    exit /b 1
)

echo.
echo [2/2] Deploying Cloud Functions...
cd ..
call firebase deploy --only functions
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Deployment failed
    pause
    exit /b 1
)

echo.
echo ========================================
echo   ✅ DEPLOYMENT SUCCESSFUL!
echo ========================================
echo.
echo Changes Deployed:
echo  ✅ Cloud Functions send photo URLs + message data
echo  ✅ Background handler shows rich local notifications
echo  ✅ InboxStyle for grouped messages (like WhatsApp)
echo  ✅ Profile pictures in notifications
echo.
echo Next: Hot restart your app to apply changes
echo.
echo Test it:
echo  1. Put app in background
echo  2. Send 3 messages from another device
echo  3. You'll see ONE notification with all 3 messages! ✅
echo.
pause

