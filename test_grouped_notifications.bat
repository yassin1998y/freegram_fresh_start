@echo off
REM Test Grouped FCM Notifications
REM This script helps verify the notification improvements

echo ========================================
echo  Testing Grouped Notifications
echo ========================================
echo.

echo MANUAL TESTING CHECKLIST:
echo.
echo [Message Grouping]
echo  □ 1. Send multiple messages from one user
echo  □ 2. Check notification shows grouped conversation (up to 10 messages)
echo  □ 3. Verify "X messages" count is displayed correctly
echo  □ 4. Confirm older messages appear at the top
echo.
echo [Notification Style]
echo  □ 5. Check WhatsApp-style MessagingStyle format
echo  □ 6. Verify sender profile picture appears
echo  □ 7. Confirm messages show sender name correctly
echo  □ 8. Check "You:" prefix for your own messages
echo.
echo [Action Buttons]
echo  □ 9. Test "Reply" button opens chat
echo  □ 10. Test "Mark as Read" dismisses notification
echo  □ 11. Verify notification updates when read
echo.
echo [Multiple Chats]
echo  □ 12. Send messages from different users
echo  □ 13. Check each chat has separate notification
echo  □ 14. Verify notifications are properly grouped by chat
echo.
echo [Friend Requests]
echo  □ 15. Send friend request
echo  □ 16. Check notification with "Accept" button
echo  □ 17. Test accepting from notification
echo.
echo ========================================
echo.
echo To view Firebase logs:
echo   firebase functions:log --only sendMessageNotification
echo.
echo To test FCM directly:
echo   Use Firebase Console ^> Cloud Messaging ^> Send Test Message
echo.
pause

