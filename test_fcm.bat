@echo off
REM Test FCM Cloud Functions Deployment
echo ========================================
echo   Testing FCM Deployment
echo ========================================
echo.

echo [1/4] Checking functions list...
echo.
call firebase functions:list --project prototype-29c26
if %errorlevel% neq 0 (
    echo.
    echo ❌ ERROR: Cannot list functions
    echo    Make sure you're logged in: firebase login
    pause
    exit /b 1
)
echo.
echo ✅ Functions list retrieved successfully
echo.

echo [2/4] Testing HTTP endpoint...
echo.
echo Testing: https://us-central1-prototype-29c26.cloudfunctions.net/test
echo.
curl https://us-central1-prototype-29c26.cloudfunctions.net/test
echo.
echo.
echo ℹ️  Expected: JSON with "status": "ok"
echo.

echo [3/4] Checking recent logs (last 10 entries)...
echo.
call firebase functions:log --lines 10 --project prototype-29c26
echo.

echo [4/4] Checking for errors...
echo.
call firebase functions:log --only-errors --lines 5 --project prototype-29c26
if %errorlevel% equ 0 (
    echo.
    echo ℹ️  If no output above, that means NO ERRORS! ✅
)
echo.

echo ========================================
echo   ✅ Test Complete!
echo ========================================
echo.
echo VERIFICATION CHECKLIST:
echo.
echo [ ] Step 1: Did you see 4 functions listed?
echo     ✓ sendFriendRequestNotification
echo     ✓ sendMessageNotification
echo     ✓ sendRequestAcceptedNotification
echo     ✓ test
echo.
echo [ ] Step 2: Did test endpoint return JSON?
echo     Expected: {"status":"ok", "message":"..."}
echo.
echo [ ] Step 3: Are there any errors in logs?
echo     Expected: No errors
echo.
echo If all YES ✅ = Deployment Successful!
echo If any NO ❌ = Check VERIFY_DEPLOYMENT.md
echo.
pause

