$testFiles = @(
    "c:\Users\PC\StudioProjects\freegram_fresh_start\test\repositories\friend_repository_test.dart",
    "c:\Users\PC\StudioProjects\freegram_fresh_start\test\repositories\match_repository_test.dart",
    "c:\Users\PC\StudioProjects\freegram_fresh_start\test\integration\friend_request_flow_integration_test.dart",
    "c:\Users\PC\StudioProjects\freegram_fresh_start\test\integration\match_creation_flow_integration_test.dart"
)

$now = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")

foreach ($file in $testFiles) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        
        # Pattern to match UserModel constructor calls
        $pattern = '(?s)UserModel\(\s*id:\s*(\w+),\s*username:\s*''([^'']+)'',\s*email:\s*''([^'']+)'',\s*photoUrl:\s*''([^'']*)'',\s*friends:\s*(\[[^\]]*\]),\s*blockedUsers:\s*(\[[^\]]*\]),?\s*\)'
        
        $replacement = {
            param($match)
            $id = $match.Groups[1].Value
            $username = $match.Groups[2].Value
            $email = $match.Groups[3].Value
            $photoUrl = $match.Groups[4].Value
            $friends = $match.Groups[5].Value
            $blockedUsers = $match.Groups[6].Value
            
            return @"
UserModel(
            id: $id,
            username: '$username',
            email: '$email',
            photoUrl: '$photoUrl',
            friends: $friends,
            blockedUsers: $blockedUsers,
            lastSeen: DateTime.now(),
            createdAt: DateTime.now(),
            lastFreeSuperLike: DateTime.now(),
            lastNearbyDiscoveryDate: DateTime.now(),
          )
"@
        }
        
        $newContent = [regex]::Replace($content, $pattern, $replacement)
        
        if ($newContent -ne $content) {
            Set-Content -Path $file -Value $newContent -NoNewline
            Write-Host "Fixed: $file"
        }
    }
}

Write-Host "Done!"
