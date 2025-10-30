// functions/index.js
// Firebase Cloud Functions for FCM Push Notifications
// Freegram - Professional Implementation (2nd Gen)

const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onRequest} = require('firebase-functions/v2/https');
const {setGlobalOptions} = require('firebase-functions/v2');
const admin = require('firebase-admin');

admin.initializeApp();

// Set global options for all functions
setGlobalOptions({
  region: 'us-central1',
  maxInstances: 10,
});

/**
 * Send notification when a friend request is received
 * Triggered when a document is created in users/{userId}/notifications/
 */
exports.sendFriendRequestNotification = onDocumentCreated(
  'users/{userId}/notifications/{notificationId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data associated with the event');
      return null;
    }
    const context = event.params;
    try {
      const notification = snap.data();
      const receiverId = context.userId;
      const notificationId = context.notificationId;

      // Only process friend request notifications
      if (notification.type !== 'friendRequest') {
        console.log('Not a friend request notification, skipping');
        return null;
      }

      console.log(`Processing friend request notification for user ${receiverId}`);

      // Get receiver's user document
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(receiverId)
        .get();

      if (!userDoc.exists) {
        console.log('Receiver user not found');
        return null;
      }

      const userData = userDoc.data();

      // Check notification preferences
      const prefs = userData.notificationPreferences || {};
      if (prefs.allNotificationsEnabled === false || prefs.friendRequestsEnabled === false) {
        console.log('User has disabled friend request notifications');
        return null;
      }

      // Get FCM tokens - ONLY USE MOST RECENT TOKEN to prevent duplicates
      let tokens = [];
      
      // New format: array of token objects
      if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
        // Sort by timestamp (most recent first) and take only the first one
        const sortedTokens = userData.fcmTokens
          .filter(tokenObj => tokenObj && tokenObj.token)
          .sort((a, b) => {
            const timeA = a.timestamp?._seconds || 0;
            const timeB = b.timestamp?._seconds || 0;
            return timeB - timeA; // Most recent first
          });
        
        if (sortedTokens.length > 0) {
          tokens.push(sortedTokens[0].token); // ONLY the most recent token
          console.log(`Using most recent token (out of ${sortedTokens.length} total)`);
        }
      }
      
      // Fallback: single token (backward compatibility)
      if (tokens.length === 0 && userData.fcmToken) {
        tokens.push(userData.fcmToken);
      }

      if (tokens.length === 0) {
        console.log('No FCM tokens found for user');
        return null;
      }

      console.log(`Sending to ${tokens.length} device (most recent only)`);

      // Construct DATA-ONLY notification message
      const message = {
        // NO 'notification' field - data-only for custom handling
        data: {
          type: 'friendRequest',
          fromUserId: notification.fromUserId,
          fromUsername: notification.fromUsername,
          fromPhotoUrl: notification.fromUserPhotoUrl || '', // For background notifications
          notificationId: notificationId,
          screen: 'FriendsListScreen',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          // Add title and body in data for display
          title: 'New Friend Request 👋',
          body: `${notification.fromUsername} sent you a friend request`,
        },
        android: {
          priority: 'high',
          // NO automatic notification - our background handler creates it
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: userData.unreadNotificationCount || 1,
              'content-available': 1, // Silent notification for iOS
            }
          }
        },
        tokens: tokens,
      };

      // Send notification
      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`Successfully sent to ${response.successCount} device(s)`);
      console.log(`Failed to send to ${response.failureCount} device(s)`);

      // Clean up invalid tokens
      if (response.failureCount > 0) {
        const invalidTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success && 
              (resp.error.code === 'messaging/invalid-registration-token' ||
               resp.error.code === 'messaging/registration-token-not-registered')) {
            invalidTokens.push(tokens[idx]);
            console.log(`Invalid token detected: ${tokens[idx].substring(0, 20)}...`);
          }
        });

        // Remove invalid tokens
        if (invalidTokens.length > 0) {
          const batch = admin.firestore().batch();
          const userRef = admin.firestore().collection('users').doc(receiverId);
          
          invalidTokens.forEach(token => {
            batch.update(userRef, {
              fcmTokens: admin.firestore.FieldValue.arrayRemove({ token: token })
            });
          });
          
          await batch.commit();
          console.log(`Removed ${invalidTokens.length} invalid token(s)`);
        }
      }

      return response;
    } catch (error) {
      console.error('Error sending friend request notification:', error);
      return null;
    }
  }
);

/**
 * Send notification when a message is received
 * Triggered when a message is created in chats/{chatId}/messages/
 */
exports.sendMessageNotification = onDocumentCreated(
  'chats/{chatId}/messages/{messageId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data associated with the event');
      return null;
    }
    const context = event.params;
    try {
      const message = snap.data();
      const chatId = context.chatId;
      const messageId = context.messageId;

      console.log(`Processing new message in chat ${chatId}`);

      // Get chat document
      const chatDoc = await admin.firestore()
        .collection('chats')
        .doc(chatId)
        .get();

      if (!chatDoc.exists) {
        console.log('Chat not found');
        return null;
      }

      const chatData = chatDoc.data();
      
      // Find recipient (the user who didn't send the message)
      const recipientId = chatData.users.find(id => id !== message.senderId);
      if (!recipientId) {
        console.log('Recipient not found');
        return null;
      }

      // Get recipient data
      const recipientDoc = await admin.firestore()
        .collection('users')
        .doc(recipientId)
        .get();

      if (!recipientDoc.exists) {
        console.log('Recipient user not found');
        return null;
      }

      const recipientData = recipientDoc.data();

      // Check if chat is muted
      const mutedChats = recipientData.mutedChats || [];
      if (mutedChats.includes(chatId)) {
        console.log('Chat is muted');
        return null;
      }

      // Check notification preferences
      const prefs = recipientData.notificationPreferences || {};
      if (prefs.allNotificationsEnabled === false || prefs.messagesEnabled === false) {
        console.log('User has disabled message notifications');
        return null;
      }

      // Get sender data
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(message.senderId)
        .get();

      if (!senderDoc.exists) {
        console.log('Sender not found');
        return null;
      }

      const senderData = senderDoc.data();

      // ========== FETCH RECENT MESSAGES FOR GROUPING (like WhatsApp) ==========
      // Get last 10 messages from this chat for professional grouped notifications
      let recentMessages = [];
      let messageLines = [];
      
      try {
        const recentMessagesSnapshot = await admin.firestore()
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', 'desc')
          .limit(10)
          .get();

        recentMessagesSnapshot.forEach(doc => {
          const msgData = doc.data();
          if (msgData.text && msgData.text.trim() !== '') {
            recentMessages.push({
              text: msgData.text,
              senderId: msgData.senderId,
              timestamp: msgData.timestamp?._seconds || Date.now() / 1000,
            });
          }
        });

        // Reverse to get chronological order (oldest first)
        recentMessages.reverse();

        // Build formatted message lines (showing sender name for group context)
        messageLines = recentMessages.map(msg => {
          const isFromSender = msg.senderId === message.senderId;
          return isFromSender ? msg.text : `You: ${msg.text}`;
        });

        console.log(`Fetched ${recentMessages.length} recent messages for grouping`);
      } catch (queryError) {
        console.error(`Error fetching recent messages (will send single message notification): ${queryError}`);
        // Fallback: Just use the current message
        recentMessages = [{
          text: message.text || '',
          senderId: message.senderId,
          timestamp: Date.now() / 1000,
        }];
        messageLines = [message.text || ''];
      }
      // ========================================================================

      // Get FCM tokens - ONLY USE MOST RECENT TOKEN to prevent duplicates
      let tokens = [];
      if (recipientData.fcmTokens && Array.isArray(recipientData.fcmTokens)) {
        // Sort by timestamp (most recent first) and take only the first one
        const sortedTokens = recipientData.fcmTokens
          .filter(tokenObj => tokenObj && tokenObj.token)
          .sort((a, b) => {
            const timeA = a.timestamp?._seconds || 0;
            const timeB = b.timestamp?._seconds || 0;
            return timeB - timeA; // Most recent first
          });
        
        if (sortedTokens.length > 0) {
          tokens.push(sortedTokens[0].token); // ONLY the most recent token
          console.log(`Using most recent token (out of ${sortedTokens.length} total)`);
        }
      }
      if (tokens.length === 0 && recipientData.fcmToken) {
        tokens.push(recipientData.fcmToken);
      }

      if (tokens.length === 0) {
        console.log('No FCM tokens found for recipient');
        return null;
      }

      // Prepare message preview
      const messagePreview = message.imageUrl ? '📷 Photo' : (message.text || 'New message');
      const messageCount = recentMessages.length;

      // Construct DATA-ONLY notification (no automatic notification)
      // This prevents duplicate notifications (FCM auto + our custom)
      const notification = {
        // NO 'notification' field - data-only message for custom handling
        data: {
          type: 'newMessage',
          chatId: chatId,
          senderId: message.senderId,
          senderUsername: senderData.username,
          senderPhotoUrl: senderData.photoUrl || '', // For background notifications
          messageText: message.text || '', // For background notifications
          messageCount: messageCount.toString(), // ACTUAL message count
          messages: JSON.stringify(messageLines), // GROUPED MESSAGES for InboxStyle
          messageId: messageId,
          screen: 'ChatScreen',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          // Add title and body in data for display
          title: senderData.username,
          body: messagePreview,
        },
        android: {
          priority: 'high',
          // NO automatic notification - our background handler creates it
        },
        apns: {
          payload: {
            aps: {
              sound: 'message_tone.caf',
              badge: recipientData.unreadMessageCount || 1,
              'content-available': 1, // Silent notification for iOS
            }
          }
        },
        tokens: tokens,
      };

      // Send notification
      const response = await admin.messaging().sendEachForMulticast(notification);
      console.log(`Message notification sent to ${response.successCount} device(s)`);

      // Mark message as delivered if notification was successfully sent
      if (response.successCount > 0) {
        try {
          await admin.firestore()
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .update({
              isDelivered: true,
              deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          console.log(`Message ${messageId} marked as delivered`);
        } catch (err) {
          console.error('Error marking message as delivered:', err);
        }
      }

      // Update unread count
      await admin.firestore()
        .collection('users')
        .doc(recipientId)
        .update({
          unreadMessageCount: admin.firestore.FieldValue.increment(1)
        });

      // Clean up invalid tokens
      if (response.failureCount > 0) {
        const invalidTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success && 
              (resp.error.code === 'messaging/invalid-registration-token' ||
               resp.error.code === 'messaging/registration-token-not-registered')) {
            invalidTokens.push(tokens[idx]);
          }
        });

        if (invalidTokens.length > 0) {
          const batch = admin.firestore().batch();
          const userRef = admin.firestore().collection('users').doc(recipientId);
          
          invalidTokens.forEach(token => {
            batch.update(userRef, {
              fcmTokens: admin.firestore.FieldValue.arrayRemove({ token: token })
            });
          });
          
          await batch.commit();
          console.log(`Removed ${invalidTokens.length} invalid token(s)`);
        }
      }

      return response;
    } catch (error) {
      console.error('Error sending message notification:', error);
      return null;
    }
  }
);

/**
 * Send notification when a friend request is accepted
 * Triggered when a notification is created
 */
exports.sendRequestAcceptedNotification = onDocumentCreated(
  'users/{userId}/notifications/{notificationId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data associated with the event');
      return null;
    }
    const context = event.params;
    try {
      const notification = snap.data();
      const receiverId = context.userId;

      // Only process request accepted notifications
      if (notification.type !== 'requestAccepted') {
        return null;
      }

      console.log(`Processing request accepted notification for user ${receiverId}`);

      const userDoc = await admin.firestore()
        .collection('users')
        .doc(receiverId)
        .get();

      if (!userDoc.exists) {
        console.log('User not found');
        return null;
      }

      const userData = userDoc.data();

      // Check preferences
      const prefs = userData.notificationPreferences || {};
      if (prefs.allNotificationsEnabled === false || prefs.friendAcceptedEnabled === false) {
        console.log('User has disabled friend accepted notifications');
        return null;
      }

      // Get tokens - ONLY USE MOST RECENT TOKEN to prevent duplicates
      let tokens = [];
      if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
        // Sort by timestamp (most recent first) and take only the first one
        const sortedTokens = userData.fcmTokens
          .filter(tokenObj => tokenObj && tokenObj.token)
          .sort((a, b) => {
            const timeA = a.timestamp?._seconds || 0;
            const timeB = b.timestamp?._seconds || 0;
            return timeB - timeA; // Most recent first
          });
        
        if (sortedTokens.length > 0) {
          tokens.push(sortedTokens[0].token); // ONLY the most recent token
          console.log(`Using most recent token (out of ${sortedTokens.length} total)`);
        }
      }
      if (tokens.length === 0 && userData.fcmToken) {
        tokens.push(userData.fcmToken);
      }

      if (tokens.length === 0) {
        console.log('No tokens found');
        return null;
      }

      const message = {
        // NO 'notification' field - data-only for custom handling
        data: {
          type: 'requestAccepted',
          fromUserId: notification.fromUserId,
          fromUsername: notification.fromUsername,
          fromPhotoUrl: notification.fromUserPhotoUrl || '', // For background notifications
          screen: 'ProfileScreen',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          // Add title and body in data for display
          title: 'Friend Request Accepted ✅',
          body: `${notification.fromUsername} accepted your friend request`,
        },
        android: {
          priority: 'default',
          // NO automatic notification - our background handler creates it
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: userData.unreadNotificationCount || 1,
              'content-available': 1, // Silent notification for iOS
            }
          }
        },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`Sent to ${response.successCount} device(s)`);

      return response;
    } catch (error) {
      console.error('Error sending request accepted notification:', error);
      return null;
    }
  }
);

/**
 * Test endpoint to verify Cloud Functions are working
 */
exports.test = onRequest(async (req, res) => {
  res.json({
    status: 'ok',
    message: 'Firebase Cloud Functions are working! 🚀 (2nd Gen)',
    timestamp: new Date().toISOString(),
    functions: [
      'sendFriendRequestNotification',
      'sendMessageNotification',
      'sendRequestAcceptedNotification'
    ],
    generation: '2nd Gen',
    region: 'us-central1'
  });
});

