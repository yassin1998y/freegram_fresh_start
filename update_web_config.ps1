# Helper script to update web Firebase configuration
# Usage: Run this script and paste your Firebase web config

Write-Host "`n=== WEB FIREBASE CONFIGURATION UPDATER ===" -ForegroundColor Cyan
Write-Host "`nPlease paste your Firebase web app configuration from Firebase Console" -ForegroundColor Yellow
Write-Host "It should look like this:" -ForegroundColor White
Write-Host "`nconst firebaseConfig = {" -ForegroundColor Gray
Write-Host "  apiKey: 'AIzaSy...'," -ForegroundColor Gray
Write-Host "  authDomain: 'project.firebaseapp.com'," -ForegroundColor Gray
Write-Host "  projectId: 'project-id'," -ForegroundColor Gray
Write-Host "  storageBucket: 'project.appspot.com'," -ForegroundColor Gray
Write-Host "  messagingSenderId: '123456789'," -ForegroundColor Gray
Write-Host "  appId: '1:123456789:web:abc123'," -ForegroundColor Gray
Write-Host "  measurementId: 'G-XXXXXXXXXX'" -ForegroundColor Gray
Write-Host "};" -ForegroundColor Gray
Write-Host "`nOr provide the values one by one:" -ForegroundColor Yellow
Write-Host ""

$apiKey = Read-Host "Enter API Key"
$appId = Read-Host "Enter App ID (format: 1:XXXXX:web:XXXXX)"
$messagingSenderId = Read-Host "Enter Messaging Sender ID"
$projectId = Read-Host "Enter Project ID"
$authDomain = Read-Host "Enter Auth Domain (or press Enter for default: $projectId.firebaseapp.com)"
if ([string]::IsNullOrWhiteSpace($authDomain)) {
    $authDomain = "$projectId.firebaseapp.com"
}
$databaseURL = Read-Host "Enter Database URL (or press Enter to skip)"
$storageBucket = Read-Host "Enter Storage Bucket (or press Enter for default: $projectId.firebasestorage.app)"
if ([string]::IsNullOrWhiteSpace($storageBucket)) {
    $storageBucket = "$projectId.firebasestorage.app"
}
$measurementId = Read-Host "Enter Measurement ID (or press Enter to skip)"

Write-Host "`n=== EXTRACTED VALUES ===" -ForegroundColor Green
Write-Host "API Key: $apiKey"
Write-Host "App ID: $appId"
Write-Host "Messaging Sender ID: $messagingSenderId"
Write-Host "Project ID: $projectId"
Write-Host "Auth Domain: $authDomain"
Write-Host "Database URL: $databaseURL"
Write-Host "Storage Bucket: $storageBucket"
Write-Host "Measurement ID: $measurementId"

Write-Host "`nThese values will be used to update:" -ForegroundColor Yellow
Write-Host "  1. firebase.json"
Write-Host "  2. lib/firebase_options.dart"
Write-Host "  3. web/firebase-messaging-sw.js"
Write-Host "  4. .env file"

$confirm = Read-Host "`nProceed with update? (y/n)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "Update cancelled." -ForegroundColor Yellow
    exit
}

# Export values for use by other scripts
$env:WEB_API_KEY = $apiKey
$env:WEB_APP_ID = $appId
$env:WEB_MESSAGING_SENDER_ID = $messagingSenderId
$env:WEB_PROJECT_ID = $projectId
$env:WEB_AUTH_DOMAIN = $authDomain
$env:WEB_DATABASE_URL = $databaseURL
$env:WEB_STORAGE_BUCKET = $storageBucket
$env:WEB_MEASUREMENT_ID = $measurementId

Write-Host "`n✅ Values extracted! Run the update script next." -ForegroundColor Green

