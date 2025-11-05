@echo off
REM Script to set SMTP configuration for Firebase Functions
REM Uses Firebase Secrets (recommended) or Environment Variables

echo ========================================
echo  SETTING SMTP CONFIGURATION
echo ========================================
echo.
echo This script will set SMTP secrets for Firebase Functions.
echo You'll be prompted to enter values securely.
echo.
echo Example for Gmail:
echo   - Host: smtp.gmail.com
echo   - Port: 587
echo   - User: your-email@gmail.com
echo   - Password: Use an App Password (not your regular password)
echo     (Generate at: https://myaccount.google.com/apppasswords)
echo.
pause

echo.
echo Setting SMTP_HOST...
echo Enter SMTP host (default: smtp.gmail.com):
set /p SMTP_HOST="> "
if "%SMTP_HOST%"=="" set SMTP_HOST=smtp.gmail.com

echo.
echo Setting SMTP_PORT...
echo Enter SMTP port (default: 587):
set /p SMTP_PORT="> "
if "%SMTP_PORT%"=="" set SMTP_PORT=587

echo.
echo Setting SMTP_USER...
echo Enter your email address:
set /p SMTP_USER="> "

echo.
echo Setting SMTP_PASSWORD...
echo Enter your app password:
set /p SMTP_PASSWORD="> "

echo.
echo Setting SMTP_FROM...
echo Enter sender email (default: same as SMTP_USER):
set /p SMTP_FROM="> "
if "%SMTP_FROM%"=="" set SMTP_FROM=%SMTP_USER%

echo.
echo ========================================
echo  SETTING SECRETS...
echo ========================================
echo.

REM Use Firebase Secrets (recommended for sensitive data)
echo Setting SMTP_HOST secret...
echo %SMTP_HOST% | firebase functions:secrets:set SMTP_HOST

echo Setting SMTP_PORT secret...
echo %SMTP_PORT% | firebase functions:secrets:set SMTP_PORT

echo Setting SMTP_USER secret...
echo %SMTP_USER% | firebase functions:secrets:set SMTP_USER

echo Setting SMTP_PASSWORD secret...
echo %SMTP_PASSWORD% | firebase functions:secrets:set SMTP_PASSWORD

echo Setting SMTP_FROM secret...
echo %SMTP_FROM% | firebase functions:secrets:set SMTP_FROM

echo.
echo ========================================
echo  CONFIGURATION SET!
echo ========================================
echo.
echo NOTE: You'll need to grant secrets access in your functions.
echo Update functions/index.js to reference these secrets.
echo.

pause

