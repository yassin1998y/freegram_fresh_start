@echo off
REM Deploy Message Status & Notification Upgrade
REM Includes: Delivery tracking, auto-mark as seen, duplicate fix

echo ========================================
echo  Message Status Upgrade Deployment
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
echo Deploying: sendMessageNotification (with delivery tracking)
call firebase deploy --only functions:sendMessageNotification
if %errorlevel% neq 0 (
    echo Error: Deploy failed
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
echo  ✓ Messages marked as delivered when notification sent
echo  ✓ Auto-mark as seen when viewing chat (WhatsApp-style)
echo  ✓ Mark as Read button properly updates Firestore
echo  ✓ Fixed duplicate notification issue
echo  ✓ Professional message status indicators
echo.
echo Next Steps:
echo  1. Build and run Flutter app
echo  2. Test message status indicators
echo  3. Test auto-mark as seen (open chat)
echo  4. Test Mark as Read button in notification
echo  5. Verify no duplicate notifications
echo.
echo Test Checklist:
echo  [_] Send message → Shows single check (sent)
echo  [_] Recipient receives → Shows double check gray (delivered)
echo  [_] Recipient opens chat → Shows double check blue (seen)
echo  [_] Test Mark as Read button → Messages marked as seen
echo  [_] Send multiple messages → No duplicate notifications
echo.
pause

