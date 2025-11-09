# PowerShell script to capture Flutter debug logs from Samsung device
# Usage: .\scripts\capture_logs.ps1

Write-Host "Capturing Flutter debug logs from Samsung device..." -ForegroundColor Green
Write-Host "Device: SM A155F (R58X20FBRJX)" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop capturing logs" -ForegroundColor Yellow
Write-Host ""

$logFile = "debug_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Write-Host "Log file: $logFile" -ForegroundColor Cyan
Write-Host ""

# Capture logs with filtering for our fixes
flutter logs --device-id R58X20FBRJX 2>&1 | Tee-Object -FilePath $logFile

Write-Host ""
Write-Host "Logs saved to: $logFile" -ForegroundColor Green

