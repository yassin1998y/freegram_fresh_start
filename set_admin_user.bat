@echo off
REM Script to set an admin user in Firestore
REM Usage: Edit this file and replace USER_ID with the actual user ID

echo ========================================
echo  SETTING ADMIN USER IN FIRESTORE
echo ========================================
echo.
echo This will set a user as admin in Firestore.
echo.
echo You need to:
echo   1. Edit this file and replace USER_ID with the actual user ID
echo   2. Or manually add to Firestore:
echo      Collection: users
echo      Document: USER_ID
echo      Field: role = "admin" (or isAdmin = true)
echo.
echo Alternatively, you can use Firebase Console:
echo   1. Go to Firestore Database
echo   2. Navigate to users/{userId}
echo   3. Add field: role = "admin"
echo.
pause



