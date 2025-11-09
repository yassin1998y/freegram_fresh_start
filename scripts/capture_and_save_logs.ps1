# PowerShell script to capture and save Flutter debug logs
# Usage: .\scripts\capture_and_save_logs.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Flutter Debug Log Capture" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$deviceId = "R58X20FBRJX"
$logFile = "debug_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

Write-Host "Device: Samsung SM A155F ($deviceId)" -ForegroundColor Yellow
Write-Host "Log file: $logFile" -ForegroundColor Yellow
Write-Host ""
Write-Host "Instructions:" -ForegroundColor Cyan
Write-Host "1. This will capture all Flutter logs from your Samsung device" -ForegroundColor White
Write-Host "2. Use the app normally (especially reels and stories)" -ForegroundColor White
Write-Host "3. Press Ctrl+C to stop capturing" -ForegroundColor White
Write-Host "4. The log file will be saved in the project root" -ForegroundColor White
Write-Host "5. Share the log file content with me" -ForegroundColor White
Write-Host ""
Write-Host "Starting log capture in 3 seconds..." -ForegroundColor Green
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "Capturing logs... (Press Ctrl+C to stop)" -ForegroundColor Green
Write-Host ""

# Capture logs and save to file
try {
    flutter logs --device-id $deviceId 2>&1 | Tee-Object -FilePath $logFile
} catch {
    Write-Host ""
    Write-Host "Log capture stopped." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Log capture complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Log file saved to: $logFile" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Open the file: $logFile" -ForegroundColor White
Write-Host "2. Copy all the content (Ctrl+A, Ctrl+C)" -ForegroundColor White
Write-Host "3. Paste it in the chat with me" -ForegroundColor White
Write-Host ""

