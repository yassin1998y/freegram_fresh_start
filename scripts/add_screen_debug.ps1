# PowerShell script to add debug logging to all screens
# This script adds debugPrint('📱 SCREEN: filename.dart') to all screen files

$screenFiles = Get-ChildItem -Path "lib\screens" -Filter "*_screen.dart"

foreach ($file in $screenFiles) {
    $content = Get-Content $file.FullName -Raw
    $fileName = $file.Name
    
    # Check if debug already exists
    if ($content -match "📱 SCREEN:") {
        Write-Host "✓ Already has debug: $fileName" -ForegroundColor Green
        continue
    }
    
    # Pattern 1: StatelessWidget with build method
    if ($content -match "(class\s+\w+Screen\s+extends\s+StatelessWidget[\s\S]*?@override\s+Widget\s+build\(BuildContext\s+context\)\s+\{)" -and 
        $content -notmatch "📱 SCREEN:") {
        $content = $content -replace "(@override\s+Widget\s+build\(BuildContext\s+context\)\s+\{)", "`$1`n    debugPrint('📱 SCREEN: $fileName');"
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "✓ Added debug to StatelessWidget: $fileName" -ForegroundColor Yellow
        continue
    }
    
    # Pattern 2: StatefulWidget with initState
    if ($content -match "(class\s+\w+Screen\s+extends\s+StatefulWidget)" -and 
        $content -match "(@override\s+void\s+initState\(\)\s+\{)" -and
        $content -notmatch "📱 SCREEN:") {
        $content = $content -replace "(@override\s+void\s+initState\(\)\s+\{\s+super\.initState\(\);)", "`$1`n    debugPrint('📱 SCREEN: $fileName');"
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "✓ Added debug to StatefulWidget: $fileName" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "⚠ Could not auto-add to: $fileName" -ForegroundColor Red
}

Write-Host "`nDone! Check files manually if needed." -ForegroundColor Cyan

