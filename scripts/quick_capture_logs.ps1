# Quick log capture - captures last 1000 lines
Write-Host "Capturing Flutter logs from Samsung device..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop after you've tested the app" -ForegroundColor Yellow
Write-Host ""

$logFile = "debug_output.txt"
Write-Host "Logs will be saved to: $logFile" -ForegroundColor Cyan
Write-Host ""

# Capture logs and display them
flutter logs --device-id R58X20FBRJX 2>&1 | Tee-Object -FilePath $logFile

Write-Host ""
Write-Host "Logs saved! Now copy the content of $logFile and share it with me." -ForegroundColor Green

