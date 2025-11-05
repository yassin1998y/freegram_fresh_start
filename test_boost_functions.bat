@echo off
REM Test Boost Post Cloud Functions
echo ========================================
echo   Testing Boost Post Cloud Functions
echo ========================================
echo.

echo [1/4] Checking deployed functions...
echo.
firebase functions:list | findstr /i "boost"
echo.

echo [2/4] Checking recent logs for boost functions...
echo.
echo --- trackBoostImpression logs ---
firebase functions:log | findstr /i "trackBoostImpression" | findstr /v "audit"
echo.

echo --- trackBoostEngagement logs ---
firebase functions:log | findstr /i "trackBoostEngagement" | findstr /v "audit"
echo.

echo --- cleanupExpiredBoosts logs ---
firebase functions:log | findstr /i "cleanupExpiredBoosts" | findstr /v "audit"
echo.

echo [3/4] Function Status Check...
echo.
echo Checking if functions are active in Firebase Console...
echo Visit: https://console.firebase.google.com/project/prototype-29c26/functions
echo.

echo [4/4] Testing Instructions...
echo.
echo ========================================
echo   TESTING GUIDE
echo ========================================
echo.
echo FUNCTION 1: trackBoostImpression (Callable)
echo   - Add cloud_functions package to pubspec.yaml
echo   - Call from Flutter app when viewing boosted post
echo   - Or test via Firebase Console Test function
echo.
echo FUNCTION 2: trackBoostEngagement (Trigger)
echo   - Automatically triggers when user reacts to boosted post
echo   - Test by: Like/react to a boosted post in app
echo   - Check logs: firebase functions:log
echo.
echo FUNCTION 3: cleanupExpiredBoosts (Scheduled)
echo   - Runs automatically every 24 hours
echo   - To test manually: Go to Cloud Scheduler and "Run now"
echo   - Or wait 24 hours and check logs
echo.
echo ========================================
echo   ✅ Test Complete!
echo ========================================
echo.
pause

