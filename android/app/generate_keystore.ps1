# PowerShell script to generate Android release keystore
# This script finds Java and creates a keystore for signing release builds

Write-Host "Generating Android Release Keystore..." -ForegroundColor Green

# Try to find Java from common locations
$javaPaths = @(
    "$env:JAVA_HOME\bin\keytool.exe",
    "$env:ANDROID_HOME\jbr\bin\keytool.exe",
    "$env:LOCALAPPDATA\Android\Sdk\jbr\bin\keytool.exe",
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe",
    "C:\Program Files\Java\*\bin\keytool.exe"
)

$keytool = $null
foreach ($path in $javaPaths) {
    if (Test-Path $path) {
        $keytool = $path
        break
    }
    # Handle wildcards
    $resolved = Resolve-Path $path -ErrorAction SilentlyContinue
    if ($resolved) {
        $keytool = $resolved[0].Path
        break
    }
}

# If still not found, try to find it in PATH
if (-not $keytool) {
    $keytool = Get-Command keytool -ErrorAction SilentlyContinue
    if ($keytool) {
        $keytool = $keytool.Source
    }
}

if (-not $keytool -or -not (Test-Path $keytool)) {
    Write-Host "ERROR: keytool not found!" -ForegroundColor Red
    Write-Host "Please ensure Java JDK is installed and JAVA_HOME is set, or Android Studio is installed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "You can also manually create the keystore using:" -ForegroundColor Yellow
    Write-Host 'keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias freegram-release-key' -ForegroundColor Cyan
    exit 1
}

Write-Host "Found keytool at: $keytool" -ForegroundColor Green
Write-Host ""

# Check if keystore already exists
if (Test-Path "upload-keystore.jks") {
    Write-Host "WARNING: upload-keystore.jks already exists!" -ForegroundColor Yellow
    $overwrite = Read-Host "Do you want to overwrite it? (yes/no)"
    if ($overwrite -ne "yes") {
        Write-Host "Keystore generation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Prompt for passwords
Write-Host "Enter keystore information:" -ForegroundColor Cyan
$storePassword = Read-Host "Keystore password" -AsSecureString
$storePasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePassword))

$keyPassword = Read-Host "Key password (can be same as keystore password)" -AsSecureString
$keyPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPassword))

Write-Host ""
Write-Host "Generating keystore..." -ForegroundColor Green

# Generate the keystore
$keytoolArgs = @(
    "-genkey",
    "-v",
    "-keystore", "upload-keystore.jks",
    "-keyalg", "RSA",
    "-keysize", "2048",
    "-validity", "10000",
    "-alias", "freegram-release-key",
    "-storepass", $storePasswordPlain,
    "-keypass", $keyPasswordPlain,
    "-dname", "CN=Freegram, OU=Development, O=Freegram, L=Unknown, S=Unknown, C=US"
)

& $keytool $keytoolArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ Keystore generated successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Copy key.properties.template to key.properties" -ForegroundColor Yellow
    Write-Host "2. Update key.properties with your passwords" -ForegroundColor Yellow
    Write-Host "3. Run: .\gradlew signingReport (from android directory) to get SHA keys" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "IMPORTANT: Keep your keystore and passwords secure!" -ForegroundColor Red
    Write-Host "          Add key.properties to .gitignore (already done)" -ForegroundColor Red
} else {
    Write-Host ""
    Write-Host "ERROR: Failed to generate keystore!" -ForegroundColor Red
    exit 1
}

