#!/bin/bash
# Bash script to capture Flutter debug logs from Samsung device
# Usage: ./scripts/capture_logs.sh

echo "Capturing Flutter debug logs from Samsung device..."
echo "Device: SM A155F (R58X20FBRJX)"
echo "Press Ctrl+C to stop capturing logs"
echo ""

LOG_FILE="debug_log_$(date +%Y%m%d_%H%M%S).txt"
echo "Log file: $LOG_FILE"
echo ""

# Capture logs with filtering for our fixes
flutter logs --device-id R58X20FBRJX 2>&1 | tee "$LOG_FILE"

echo ""
echo "Logs saved to: $LOG_FILE"

