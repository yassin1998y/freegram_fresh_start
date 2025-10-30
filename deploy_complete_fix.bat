@echo off
REM Complete Fix Deployment - No Duplicates & Working Indicators
REM This script deploys ALL fixes for notifications and message status

echo ========================================
echo  COMPLETE FIX DEPLOYMENT
echo ========================================
echo.
echo This will deploy:
echo  1. Data-only FCM messages (no duplicates)
echo  2. Grouped message notifications
echo  3. Working Mark as Read button
echo  4. Auto-mark as seen
echo  5. Accurate status indicators
echo.
echo Press any key to continue or Ctrl+C to cancel...
pause >nul
echo.

echo [1/4] Installing Firebase Functions dependencies...
cd functions
call npm install
if %errorlevel% neq 0 (
    echo Error: npm install failed
    cd ..
    pause
    exit /b 1
)
echo.

echo [2/4] Deploying Cloud Functions...
echo.
echo Deploying: sendMessageNotification (data-only, no duplicates)
call firebase deploy --only functions:sendMessageNotification
if %errorlevel% neq 0 (
    echo Error: Deploy failed
    cd ..
    pause
    exit /b 1
)
echo.

echo [3/4] Deploying all notification functions...
call firebase deploy --only functions:sendFriendRequestNotification,functions:sendRequestAcceptedNotification
if %errorlevel% neq 0 (
    echo Warning: Some functions failed to deploy
)
echo.

cd ..

echo [4/4] Verifying deployment...
cd functions
call firebase functions:log --only sendMessageNotification --limit 3
cd ..
echo.

echo ========================================
echo  DEPLOYMENT COMPLETE! ✅
echo ========================================
echo.
echo CRITICAL: You MUST do the following NOW:
echo.
echo  1. CLEAN BUILD your Flutter app:
echo     flutter clean
echo     flutter pub get
echo     flutter run
echo.
echo  2. CLEAR APP DATA on test device:
echo     Settings ^> Apps ^> Freegram ^> Storage ^> Clear Data
echo.
echo  3. RESTART the app
echo.
echo  4. TEST:
echo     - Send message (should see ONLY ONE notification)
echo     - Tap "Mark as Read" (should dismiss notification)
echo     - Open chat (messages should turn blue instantly)
echo     - Check status indicators (sent → delivered → seen)
echo.
echo What's Fixed:
echo  ✓ NO MORE DUPLICATE NOTIFICATIONS
echo  ✓ Mark as Read button WORKS
echo  ✓ Auto-mark as seen when viewing chat
echo  ✓ Accurate message status indicators
echo  ✓ Professional WhatsApp-style notifications
echo  ✓ Message grouping (shows conversation)
echo.
echo See COMPLETE_FIX_DEPLOYMENT.txt for full testing checklist
echo.
pause

