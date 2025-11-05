@echo off
REM ============================================================================
REM SIMPLE ADMIN USER SETUP GUIDE
REM ============================================================================
REM This script provides instructions for setting admin users in Firebase
REM ============================================================================

echo.
echo ============================================================================
echo  HOW TO SET ADMIN USERS IN FIREBASE
echo ============================================================================
echo.
echo METHOD 1: Firebase Console (Easiest)
echo -------------------------------------
echo   1. Go to: https://console.firebase.google.com/project/prototype-29c26/firestore
echo   2. Navigate to: users collection
echo   3. Open the user document you want to make admin
echo   4. Click "Add field"
echo   5. Add ONE of these fields:
echo.
echo      Option A:
echo        Field name: role
echo        Type: string
echo        Value: admin
echo.
echo      Option B:
echo        Field name: isAdmin
echo        Type: boolean
echo        Value: true
echo.
echo   6. Click "Update"
echo.
echo ============================================================================
echo.
echo METHOD 2: Using Admin SDK Script
echo ----------------------------------
echo   1. Download service account key from:
echo      https://console.firebase.google.com/project/prototype-29c26/settings/serviceaccounts/adminsdk
echo.
echo   2. Save it as: functions/serviceAccountKey.json
echo.
echo   3. Run: node scripts/set_admin_user.js ^<USER_ID^>
echo.
echo ============================================================================
echo.
echo VERIFY ADMIN STATUS:
echo ---------------------
echo   Admin users can approve/reject page verification requests
echo   Test by calling the verification endpoint with their auth token
echo.
echo ============================================================================
echo.
echo For detailed instructions, see: HOW_TO_SET_ADMIN_USERS.md
echo.
pause



