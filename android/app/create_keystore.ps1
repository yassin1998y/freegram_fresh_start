# Simple script to generate Android release keystore
$keytool = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"

if (-not (Test-Path $keytool)) {
    Write-Host "ERROR: keytool not found at: $keytool" -ForegroundColor Red
    Write-Host "Please ensure Android Studio is installed." -ForegroundColor Yellow
    exit 1
}

Write-Host "Generating Android Release Keystore..." -ForegroundColor Green
Write-Host "You will be prompted to enter:" -ForegroundColor Cyan
Write-Host "  1. Keystore password (enter twice)" -ForegroundColor Yellow
Write-Host "  2. Key password (can be same as keystore password)" -ForegroundColor Yellow
Write-Host "  3. Your name and organization details" -ForegroundColor Yellow
Write-Host ""

& $keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias freegram-release-key

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Keystore generated successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Remember the passwords you entered" -ForegroundColor Yellow
    Write-Host "2. Copy key.properties.template to key.properties" -ForegroundColor Yellow
    Write-Host "3. Edit key.properties and add your passwords" -ForegroundColor Yellow
    Write-Host "4. Run: cd .. ; .\gradlew signingReport" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "ERROR: Failed to generate keystore!" -ForegroundColor Red
}

