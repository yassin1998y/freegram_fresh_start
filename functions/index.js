// functions/index.js
// Firebase Cloud Functions for FCM Push Notifications
// Freegram - Professional Implementation (2nd Gen)

const {onDocumentCreated, onDocumentWritten, onDocumentDeleted} = require('firebase-functions/v2/firestore');
const {onRequest, onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {setGlobalOptions} = require('firebase-functions/v2');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

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

      const receiverData = userDoc.data();

      // Check notification preferences
      const prefs = receiverData.notificationPreferences || {};
      if (prefs.allNotificationsEnabled === false || prefs.friendRequestsEnabled === false) {
        console.log('User has disabled friend request notifications');
        return null;
      }

      // Get sender data
      const fromUserId = notification.fromUserId;
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(fromUserId)
        .get();

      if (!senderDoc.exists) {
        console.log('Sender user not found');
        return null;
      }

      const senderData = senderDoc.data();

      // Get FCM token(s) - check both single token and tokens array
      let tokens = [];
      if (receiverData.fcmTokens && Array.isArray(receiverData.fcmTokens)) {
        tokens = receiverData.fcmTokens;
      } else if (receiverData.fcmToken) {
        tokens = [receiverData.fcmToken];
      }

      if (tokens.length === 0 && receiverData.fcmToken) {
        tokens.push(receiverData.fcmToken);
      }

      if (tokens.length === 0) {
        console.log('No FCM tokens found for recipient');
        return null;
      }

      const message = {
        // NO 'notification' field - data-only message for custom handling
        data: {
          type: 'friendRequest',
          fromUserId: fromUserId,
          fromUsername: senderData.username || 'Someone',
          fromPhotoUrl: senderData.photoUrl || '',
          notificationId: notificationId,
          screen: 'ProfileScreen',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: receiverData.unreadNotificationCount || 1,
              'content-available': 1,
            }
          }
        },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`Sent friend request notification to ${response.successCount} device(s)`);

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
        console.log('Sender user not found');
        return null;
      }

      const senderData = senderDoc.data();

      // Get last 10 messages for grouped notification
      const messagesSnapshot = await admin.firestore()
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', 'desc')
        .limit(10)
        .get();

      const recentMessages = [];
      const messageLines = [];
      
      messagesSnapshot.docs.forEach((doc) => {
        const msg = doc.data();
        const isFromRecipient = msg.senderId === recipientId;
        const senderName = isFromRecipient ? 'You' : senderData.username;
        recentMessages.push(msg);
        messageLines.push(`${senderName}: ${msg.text || '📷 Photo'}`);
      });

      messageLines.reverse(); // Show oldest first

      // Get FCM token(s) - check both single token and tokens array
      let tokens = [];
      if (recipientData.fcmTokens && Array.isArray(recipientData.fcmTokens)) {
        tokens = recipientData.fcmTokens;
      } else if (recipientData.fcmToken) {
        tokens = [recipientData.fcmToken];
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
              badge: recipientData.unreadNotificationCount || 1,
              'content-available': 1, // Silent notification for iOS
            }
          }
        },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(notification);
      console.log(`Sent message notification to ${response.successCount} device(s)`);

      return response;
    } catch (error) {
      console.error('Error sending message notification:', error);
      return null;
    }
  }
);

/**
 * Send notification when a friend request is accepted
 * Triggered when a document is created in users/{userId}/notifications/
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
        console.log('Not a request accepted notification, skipping');
        return null;
      }

      console.log(`Processing request accepted notification for user ${receiverId}`);

      // Get receiver's user document
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(receiverId)
        .get();

      if (!userDoc.exists) {
        console.log('Receiver user not found');
        return null;
      }

      const receiverData = userDoc.data();

      // Check notification preferences
      const prefs = receiverData.notificationPreferences || {};
      if (prefs.allNotificationsEnabled === false || prefs.friendRequestsEnabled === false) {
        console.log('User has disabled friend request notifications');
        return null;
      }

      // Get sender data
      const fromUserId = notification.fromUserId;
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(fromUserId)
        .get();

      if (!senderDoc.exists) {
        console.log('Sender user not found');
        return null;
      }

      const senderData = senderDoc.data();
      const fromUsername = senderData.username || 'Someone';
      const fromPhotoUrl = senderData.photoUrl || '';

      // Get FCM token(s)
      let tokens = [];
      if (receiverData.fcmTokens && Array.isArray(receiverData.fcmTokens)) {
        tokens = receiverData.fcmTokens;
      } else if (receiverData.fcmToken) {
        tokens = [receiverData.fcmToken];
      }
      if (tokens.length === 0 && receiverData.fcmToken) {
        tokens.push(receiverData.fcmToken);
      }

      if (tokens.length === 0) {
        console.log('No FCM tokens found for recipient');
        return null;
      }

      const message = {
        data: {
          type: 'requestAccepted',
          fromUserId: fromUserId,
          fromUsername: fromUsername,
          fromPhotoUrl: fromPhotoUrl,
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
    message: 'Cloud Functions are working!',
    timestamp: new Date().toISOString(),
  });
});

/**
 * Calculate initial trending score and fan-out to personalized feeds when a post is created
 * Triggered when a document is created in posts/{postId}
 * Phase 2: Enhanced with fan-out pattern for ranking algorithm
 */
exports.onPostCreated = onDocumentCreated(
  'posts/{postId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data associated with the event');
      return null;
    }
    const context = event.params;
    try {
      const postId = context.postId;
      const postData = snap.data();

      // Calculate initial trending score based on recency
      // Formula: 100 - ageInHours (for the first hour)
      const timestamp = postData.timestamp;
      if (!timestamp) {
        console.log('Post has no timestamp');
        return null;
      }

      const postTime = timestamp.toDate();
      const now = new Date();
      const ageInHours = (now - postTime) / (1000 * 60 * 60);

      // Initial score: 100 - ageInHours (higher for newer posts)
      // Minimum score of 0
      const initialTrendingScore = Math.max(0, 100 - ageInHours);

      // Phase 2: Calculate contentWeight (w) for ranking algorithm
      const contentWeight = calculateContentWeight(postData);

      // Update post with initial trending score and contentWeight
      await admin.firestore()
        .collection('posts')
        .doc(postId)
        .update({
          trendingScore: initialTrendingScore,
          contentWeight: contentWeight,
          contentType: inferContentType(postData),
          lastEngagementTimestamp: admin.firestore.FieldValue.serverTimestamp()
        });

      console.log(`Set initial trending score for post ${postId}: ${initialTrendingScore}, contentWeight: ${contentWeight}`);

      // Phase 2: Fan-out to followers' personalized feeds
      const authorId = postData.authorId;
      const pageId = postData.pageId || null;
      const followers = await getFollowers(authorId, pageId);

      if (followers.length > 0) {
        console.log(`Fanning out post ${postId} to ${followers.length} followers`);
        
        // Fan-out in batches (500 at a time - Firestore batch limit)
        const batchSize = 500;
        for (let i = 0; i < followers.length; i += batchSize) {
          const batch = followers.slice(i, i + batchSize);
          await fanOutToFollowers(
            postId,
            authorId,
            pageId,
            contentWeight,
            batch
          );
        }
        
        console.log(`Completed fan-out for post ${postId}`);
      }

      // Handle mention notifications
      const mentions = postData.mentions || [];
      if (mentions.length > 0) {
        const authorId = postData.authorId;
        const postContent = postData.content || '';

        // Get author data
        const authorDoc = await admin.firestore()
          .collection('users')
          .doc(authorId)
          .get();

        if (authorDoc.exists) {
          const authorData = authorDoc.data();

          // Send notification to each mentioned user
          const notificationPromises = mentions.map(async (mentionedUserId) => {
            if (mentionedUserId === authorId) {
              return null; // Don't notify if user mentions themselves
            }

            const mentionedUserDoc = await admin.firestore()
              .collection('users')
              .doc(mentionedUserId)
              .get();

            if (!mentionedUserDoc.exists) {
              return null;
            }

            const mentionedUserData = mentionedUserDoc.data();

            // Check notification preferences
            const prefs = mentionedUserData.notificationPreferences || {};
            if (prefs.allNotificationsEnabled === false || prefs.mentionsEnabled === false) {
              return null;
            }

            // Create notification document
            await admin.firestore()
              .collection('users')
              .doc(mentionedUserId)
              .collection('notifications')
              .add({
                type: 'mention',
                fromUserId: authorId,
                fromUsername: authorData.username || 'Someone',
                fromUserPhotoUrl: authorData.photoUrl || '',
                postId: postId,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                read: false,
              });

            // Get FCM token(s)
            let tokens = [];
            if (mentionedUserData.fcmTokens && Array.isArray(mentionedUserData.fcmTokens)) {
              tokens = mentionedUserData.fcmTokens;
            } else if (mentionedUserData.fcmToken) {
              tokens = [mentionedUserData.fcmToken];
            }

            if (tokens.length > 0) {
              const message = {
                data: {
                  type: 'mention',
                  fromUserId: authorId,
                  fromUsername: authorData.username || 'Someone',
                  postId: postId,
                },
                notification: {
                  title: `${authorData.username || 'Someone'} mentioned you in a post`,
                  body: postContent.length > 100 ? postContent.substring(0, 100) + '...' : postContent,
                },
                tokens: tokens,
              };

              await admin.messaging().sendEachForMulticast(message);
            }

            return null;
          });

          await Promise.all(notificationPromises);
        }
      }

      return null;
    } catch (error) {
      console.error('Error in onPostCreated:', error);
      return null;
    }
  }
);

/**
 * Recalculate trending score when post engagement changes
 * Triggered when a document is written in posts/{postId}/reactions/{reactionId} or posts/{postId}/comments/{commentId}
 */
exports.onPostEngagement = onDocumentWritten(
  ['posts/{postId}/reactions/{reactionId}', 'posts/{postId}/comments/{commentId}'],
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data associated with the event');
      return null;
    }
    const context = event.params;
    try {
      const postId = context.postId;

      // Get the post document
      const postDoc = await admin.firestore()
        .collection('posts')
        .doc(postId)
        .get();

      if (!postDoc.exists) {
        console.log('Post not found');
        return null;
      }

      const postData = postDoc.data();

      // Get latest reaction count and comment count from the post
      const reactionCount = postData.reactionCount || 0;
      const commentCount = postData.commentCount || 0;

      // Get post timestamp
      const timestamp = postData.timestamp;
      if (!timestamp) {
        console.log('Post has no timestamp');
        return null;
      }

      const postTime = timestamp.toDate();
      const now = new Date();
      const ageInHours = (now - postTime) / (1000 * 60 * 60);

      // Calculate recency bonus (decays over time)
      // Formula: max(0, 100 - ageInHours)
      const recencyBonus = Math.max(0, 100 - ageInHours);

      // Calculate trending score
      // Formula: (reactions * 1) + (comments * 2) + recencyBonus
      const trendingScore = (reactionCount * 1) + (commentCount * 2) + recencyBonus;

      // Update post with new trending score
      await admin.firestore()
        .collection('posts')
        .doc(postId)
        .update({
          trendingScore: trendingScore,
          lastEngagementTimestamp: admin.firestore.FieldValue.serverTimestamp()
        });

      console.log(`Updated trending score for post ${postId}: ${trendingScore} (reactions: ${reactionCount}, comments: ${commentCount})`);
      return null;
    } catch (error) {
      console.error('Error updating trending score on engagement:', error);
      return null;
    }
  }
);

/**
 * Send notification when someone comments on a post
 * Triggered when a comment is created in posts/{postId}/comments/{commentId}
 * Phase 2: Enhanced with affinity update
 */
exports.sendCommentNotification = onDocumentCreated(
  'posts/{postId}/comments/{commentId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data associated with the event');
      return null;
    }
    const context = event.params;
    try {
      const postId = context.postId;
      const commentId = context.commentId;
      const commentData = snap.data();

      // Skip if comment is deleted or invalid
      if (commentData.deleted || !commentData.userId || !commentData.postId) {
        return null;
      }

      const commenterId = commentData.userId;
      const commentText = commentData.text || '';

      // Get post document to find author
      const postDoc = await admin.firestore()
        .collection('posts')
        .doc(postId)
        .get();

      if (!postDoc.exists) {
        console.log('Post not found');
        return null;
      }

      const postData = postDoc.data();
      const postAuthorId = postData.authorId;

      // Don't send notification if user comments on their own post
      if (commenterId === postAuthorId) {
        return null;
      }

      // Get commenter data
      const commenterDoc = await admin.firestore()
        .collection('users')
        .doc(commenterId)
        .get();

      if (!commenterDoc.exists) {
        console.log('Commenter user not found');
        return null;
      }

      const commenterData = commenterDoc.data();

      // Get post author data
      const authorDoc = await admin.firestore()
        .collection('users')
        .doc(postAuthorId)
        .get();

      if (!authorDoc.exists) {
        console.log('Post author not found');
        return null;
      }

      const authorData = authorDoc.data();

      // Check notification preferences
      const prefs = authorData.notificationPreferences || {};
      if (prefs.allNotificationsEnabled === false || prefs.commentsEnabled === false) {
        console.log('User has disabled comment notifications');
        return null;
      }

      // Create notification document
      await admin.firestore()
        .collection('users')
        .doc(postAuthorId)
        .collection('notifications')
        .add({
          type: 'comment',
          fromUserId: commenterId,
          fromUsername: commenterData.username || 'Someone',
          fromUserPhotoUrl: commenterData.photoUrl || '',
          postId: postId,
          commentId: commentId,
          message: commentText,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
        });

      // Get FCM token(s)
      let tokens = [];
      if (authorData.fcmTokens && Array.isArray(authorData.fcmTokens)) {
        tokens = authorData.fcmTokens;
      } else if (authorData.fcmToken) {
        tokens = [authorData.fcmToken];
      }

      if (tokens.length === 0) {
        console.log('No FCM tokens found for recipient');
        return null;
      }

      // Send FCM notification
      const message = {
        data: {
          type: 'comment',
          fromUserId: commenterId,
          fromUsername: commenterData.username || 'Someone',
          postId: postId,
          commentId: commentId,
        },
        notification: {
          title: `${commenterData.username || 'Someone'} commented on your post`,
          body: commentText.length > 100 ? commentText.substring(0, 100) + '...' : commentText,
        },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`Sent comment notification. Success: ${response.successCount}, Failed: ${response.failureCount}`);

      // Phase 2: Update affinity when user comments on a post
      try {
        const postAuthorId = postData.authorId;
        const postPageId = postData.pageId || null;
        const targetId = postPageId || postAuthorId;
        
        // Update affinity (increment by 0.2, max 10.0)
        await updateAffinity(commenterId, targetId, 0.2);
        
        // Recalculate feed scores for this user
        await recalculateFeedScores(commenterId, targetId);
        
        console.log(`Updated affinity for user ${commenterId} -> ${targetId} (comment)`);
      } catch (affinityError) {
        console.error('Error updating affinity on comment:', affinityError);
        // Don't fail the notification if affinity update fails
      }

      return null;
    } catch (error) {
      console.error('Error sending comment notification:', error);
      return null;
    }
  }
);

/**
 * Send notification when someone reacts to a post
 * Triggered when a reaction is created in posts/{postId}/reactions/{userId}
 * Phase 2: Enhanced with affinity update
 */
exports.sendReactionNotification = onDocumentCreated(
  'posts/{postId}/reactions/{userId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data associated with the event');
      return null;
    }
    const context = event.params;
    try {
      const postId = context.postId;
      const reactorId = context.userId; // userId is the document ID in reactions subcollection

      // Get post document to find author
      const postDoc = await admin.firestore()
        .collection('posts')
        .doc(postId)
        .get();

      if (!postDoc.exists) {
        console.log('Post not found');
        return null;
      }

      const postData = postDoc.data();
      const postAuthorId = postData.authorId;

      // Don't send notification if user reacts to their own post
      if (reactorId === postAuthorId) {
        return null;
      }

      // Get reactor data
      const reactorDoc = await admin.firestore()
        .collection('users')
        .doc(reactorId)
        .get();

      if (!reactorDoc.exists) {
        console.log('Reactor user not found');
        return null;
      }

      const reactorData = reactorDoc.data();

      // Get post author data
      const authorDoc = await admin.firestore()
        .collection('users')
        .doc(postAuthorId)
        .get();

      if (!authorDoc.exists) {
        console.log('Post author not found');
        return null;
      }

      const authorData = authorDoc.data();

      // Check notification preferences
      const prefs = authorData.notificationPreferences || {};
      if (prefs.allNotificationsEnabled === false || prefs.reactionsEnabled === false) {
        console.log('User has disabled reaction notifications');
        return null;
      }

      // Create notification document
      await admin.firestore()
        .collection('users')
        .doc(postAuthorId)
        .collection('notifications')
        .add({
          type: 'reaction',
          fromUserId: reactorId,
          fromUsername: reactorData.username || 'Someone',
          fromUserPhotoUrl: reactorData.photoUrl || '',
          postId: postId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
        });

      // Get FCM token(s)
      let tokens = [];
      if (authorData.fcmTokens && Array.isArray(authorData.fcmTokens)) {
        tokens = authorData.fcmTokens;
      } else if (authorData.fcmToken) {
        tokens = [authorData.fcmToken];
      }

      if (tokens.length === 0) {
        console.log('No FCM tokens found for recipient');
        return null;
      }

      // Send FCM notification
      const message = {
        data: {
          type: 'reaction',
          fromUserId: reactorId,
          fromUsername: reactorData.username || 'Someone',
          postId: postId,
        },
        notification: {
          title: `${reactorData.username || 'Someone'} liked your post`,
          body: postData.content ? (postData.content.length > 50 ? postData.content.substring(0, 50) + '...' : postData.content) : 'Your post',
        },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`Sent reaction notification. Success: ${response.successCount}, Failed: ${response.failureCount}`);

      // Phase 2: Update affinity when user likes a post
      try {
        const postAuthorId = postData.authorId;
        const postPageId = postData.pageId || null;
        const targetId = postPageId || postAuthorId;
        
        // Update affinity (increment by 0.1, max 10.0)
        await updateAffinity(reactorId, targetId, 0.1);
        
        // Recalculate feed scores for this user
        await recalculateFeedScores(reactorId, targetId);
        
        console.log(`Updated affinity for user ${reactorId} -> ${targetId} (like)`);
      } catch (affinityError) {
        console.error('Error updating affinity on like:', affinityError);
        // Don't fail the notification if affinity update fails
      }

      return null;
    } catch (error) {
      console.error('Error sending reaction notification:', error);
      return null;
    }
  }
);

/**
 * Helper function to check if a user is an admin
 * Checks the user's 'role' field in Firestore, or 'admin' custom claim
 */
async function isAdmin(userId) {
  try {
    // Check custom claims first (set via Admin SDK)
    const user = await admin.auth().getUser(userId);
    if (user.customClaims && user.customClaims.admin === true) {
      return true;
    }

    // Check Firestore user document
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      return false;
    }

    const userData = userDoc.data();
    return userData.role === 'admin' || userData.isAdmin === true;
  } catch (error) {
    console.error('Error checking admin status:', error);
    return false;
  }
}

/**
 * Middleware to verify admin authentication
 */
async function verifyAdmin(req, res) {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return { valid: false, userId: null, error: 'Missing authorization token' };
  }

  const token = authHeader.split('Bearer ')[1];

  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    const userId = decodedToken.uid;
    const isUserAdmin = await isAdmin(userId);

    if (!isUserAdmin) {
      return { valid: false, userId: null, error: 'User is not an admin' };
    }

    return { valid: true, userId: userId, error: null };
  } catch (error) {
    console.error('Error verifying admin token:', error);
    return { valid: false, userId: null, error: 'Invalid token' };
  }
}

/**
 * Admin-only Cloud Function to approve page verification requests
 * This function should only be called by admins (requires admin role check)
 * 
 * Usage: Call via HTTP endpoint with admin auth token
 * Headers: Authorization: Bearer <admin_token>
 */
exports.approvePageVerification = onRequest(async (req, res) => {
  // Verify admin authentication
  const auth = await verifyAdmin(req, res);
  if (!auth.valid) {
    return res.status(401).json({ error: auth.error });
  }
  
  const { requestId } = req.body;
  
  if (!requestId) {
    return res.status(400).json({ error: 'Missing requestId' });
  }

  try {
    // Get verification request
    const requestDoc = await admin.firestore()
      .collection('verificationRequests')
      .doc(requestId)
      .get();

    if (!requestDoc.exists) {
      return res.status(404).json({ error: 'Verification request not found' });
    }

    const requestData = requestDoc.data();
    
    if (requestData.status !== 'pending') {
      return res.status(400).json({ 
        error: `Request is already ${requestData.status}` 
      });
    }

    const pageId = requestData.pageId;

    // Update verification request status
    await admin.firestore()
      .collection('verificationRequests')
      .doc(requestId)
      .update({
        status: 'approved',
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    // Update page verification status
    await admin.firestore()
      .collection('pages')
      .doc(pageId)
      .update({
        verificationStatus: 'verified',
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    // Update all posts from this page to include pageIsVerified flag
    const postsSnapshot = await admin.firestore()
      .collection('posts')
      .where('pageId', '==', pageId)
      .get();

    const batch = admin.firestore().batch();
    postsSnapshot.docs.forEach((postDoc) => {
      batch.update(postDoc.ref, {
        pageIsVerified: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();

    // Send email notification to page owner
    await sendVerificationEmail(pageId, 'approved');

    console.log(`Page ${pageId} verification approved by admin ${auth.userId}`);

    return res.json({ 
      success: true, 
      message: 'Page verification approved',
      pageId: pageId 
    });
  } catch (error) {
    console.error('Error approving page verification:', error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * Admin-only Cloud Function to reject page verification requests
 * 
 * Environment Variables/Secrets: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD, SMTP_FROM
 */
exports.rejectPageVerification = onRequest(async (req, res) => {
  // Verify admin authentication
  const auth = await verifyAdmin(req, res);
  if (!auth.valid) {
    return res.status(401).json({ error: auth.error });
  }
  
  const { requestId, reason } = req.body;
  
  if (!requestId) {
    return res.status(400).json({ error: 'Missing requestId' });
  }

  try {
    const requestDoc = await admin.firestore()
      .collection('verificationRequests')
      .doc(requestId)
      .get();

    if (!requestDoc.exists) {
      return res.status(404).json({ error: 'Verification request not found' });
    }

    const requestData = requestDoc.data();
    
    if (requestData.status !== 'pending') {
      return res.status(400).json({ 
        error: `Request is already ${requestData.status}` 
      });
    }

    const pageId = requestData.pageId;

    // Update verification request status
    await admin.firestore()
      .collection('verificationRequests')
      .doc(requestId)
      .update({
        status: 'rejected',
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        rejectionReason: reason || 'No reason provided',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    // Update page verification status back to unverified
    await admin.firestore()
      .collection('pages')
      .doc(pageId)
      .update({
        verificationStatus: 'unverified',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    // Update all posts from this page to remove pageIsVerified flag
    const postsSnapshot = await admin.firestore()
      .collection('posts')
      .where('pageId', '==', pageId)
      .get();

    const batch = admin.firestore().batch();
    postsSnapshot.docs.forEach((postDoc) => {
      batch.update(postDoc.ref, {
        pageIsVerified: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();

    // Send email notification to page owner
    await sendVerificationEmail(pageId, 'rejected', reason);

    console.log(`Page ${pageId} verification rejected by admin ${auth.userId}`);

    return res.json({ 
      success: true, 
      message: 'Page verification rejected',
      pageId: pageId 
    });
  } catch (error) {
    console.error('Error rejecting page verification:', error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * Send email notification for verification status changes
 * Uses environment variables for SMTP configuration
 */
async function sendVerificationEmail(pageId, status, rejectionReason = null) {
  try {
    // Get page data
    const pageDoc = await admin.firestore()
      .collection('pages')
      .doc(pageId)
      .get();

    if (!pageDoc.exists) {
      console.error('Page not found for email notification');
      return;
    }

    const pageData = pageDoc.data();
    const ownerId = pageData.ownerId;

    // Get owner user data
    const ownerDoc = await admin.firestore()
      .collection('users')
      .doc(ownerId)
      .get();

    if (!ownerDoc.exists) {
      console.error('Page owner not found for email notification');
      return;
    }

    const ownerData = ownerDoc.data();
    const ownerEmail = ownerData.email;

    if (!ownerEmail) {
      console.error('Page owner has no email address');
      return;
    }

    // Configure email transporter (using environment variables)
    // Set these in Firebase Console: Functions → Configuration → Environment Variables
    // Or via CLI: firebase functions:secrets:set SMTP_USER, SMTP_PASSWORD, etc.
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'smtp.gmail.com',
      port: parseInt(process.env.SMTP_PORT || '587'),
      secure: process.env.SMTP_SECURE === 'true' || false,
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASSWORD,
      },
    });

    // Prepare email content
    const pageName = pageData.pageName;
    let subject, html;

    if (status === 'approved') {
      subject = `Your page "${pageName}" has been verified!`;
      html = `
        <h2>Congratulations! Your page has been verified</h2>
        <p>Hello,</p>
        <p>Great news! Your page "<strong>${pageName}</strong>" has been successfully verified.</p>
        <p>Your page now displays a verified badge, which helps build trust with your followers.</p>
        <p>Thank you for using our platform!</p>
        <hr>
        <p><small>This is an automated message. Please do not reply to this email.</small></p>
      `;
    } else if (status === 'rejected') {
      subject = `Verification request for "${pageName}"`;
      html = `
        <h2>Verification Request Update</h2>
        <p>Hello,</p>
        <p>We've reviewed your verification request for "<strong>${pageName}</strong>".</p>
        <p>Unfortunately, we're unable to verify your page at this time.</p>
        ${rejectionReason ? `<p><strong>Reason:</strong> ${rejectionReason}</p>` : ''}
        <p>You can submit a new verification request after addressing the issues mentioned above.</p>
        <p>If you have any questions, please contact our support team.</p>
        <hr>
        <p><small>This is an automated message. Please do not reply to this email.</small></p>
      `;
    }

    // Send email
    await transporter.sendMail({
      from: process.env.SMTP_FROM || process.env.SMTP_USER,
      to: ownerEmail,
      subject: subject,
      html: html,
    });

    console.log(`Verification email sent to ${ownerEmail} for page ${pageId}`);
  } catch (error) {
    console.error('Error sending verification email:', error);
    // Don't throw - email failure shouldn't break the verification process
  }
}

/**
 * Cloud Function: Update story viewer count
 * Triggered when a viewer document is created in story_media/{storyId}/viewers/
 */
exports.updateStoryViewCount = onDocumentWritten(
  'story_media/{storyId}/viewers/{viewerId}',
  async (event) => {
    const beforeSnap = event.data.before;
    const afterSnap = event.data.after;
    
    // Only process if viewer was just created (not deleted)
    if (!afterSnap.exists || beforeSnap.exists) {
      return null;
    }

    try {
      const storyId = event.params.storyId;
      
      // Count viewers in subcollection
      const viewersSnapshot = await admin.firestore()
        .collection('story_media')
        .doc(storyId)
        .collection('viewers')
        .get();
      
      const viewerCount = viewersSnapshot.size;
      
      // Update story document
      await admin.firestore()
        .collection('story_media')
        .doc(storyId)
        .update({
          viewerCount: viewerCount,
        });
      
      console.log(`Updated viewer count for story ${storyId}: ${viewerCount}`);
    } catch (error) {
      console.error('Error updating story view count:', error);
    }
  }
);

/**
 * Cloud Function: Send notification when someone replies to a story
 * Triggered when a reply document is created in story_media/{storyId}/replies/
 */
exports.sendStoryReplyNotification = onDocumentCreated(
  'story_media/{storyId}/replies/{replyId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data associated with the event');
      return null;
    }

    try {
      const reply = snap.data();
      const storyId = event.params.storyId;
      
      // Get story document
      const storyDoc = await admin.firestore()
        .collection('story_media')
        .doc(storyId)
        .get();
      
      if (!storyDoc.exists) {
        console.log('Story not found');
        return null;
      }
      
      const story = storyDoc.data();
      const authorId = story.authorId;
      const replierId = reply.replierId;
      
      // Don't notify if user replied to their own story
      if (authorId === replierId) {
        console.log('User replied to own story, skipping notification');
        return null;
      }
      
      // Get author's user document
      const authorDoc = await admin.firestore()
        .collection('users')
        .doc(authorId)
        .get();
      
      if (!authorDoc.exists) {
        console.log('Author not found');
        return null;
      }
      
      const authorData = authorDoc.data();
      
      // Check notification preferences
      const prefs = authorData.notificationPreferences || {};
      if (prefs.allNotificationsEnabled === false || prefs.storyRepliesEnabled === false) {
        console.log('User has disabled story reply notifications');
        return null;
      }
      
      // Get replier's user document
      const replierDoc = await admin.firestore()
        .collection('users')
        .doc(replierId)
        .get();
      
      if (!replierDoc.exists) {
        console.log('Replier not found');
        return null;
      }
      
      const replierData = replierDoc.data();
      const replierUsername = replierData.username || 'Someone';
      
      // Get FCM token(s)
      let tokens = [];
      if (authorData.fcmTokens && Array.isArray(authorData.fcmTokens)) {
        tokens = authorData.fcmTokens;
      } else if (authorData.fcmToken) {
        tokens = [authorData.fcmToken];
      }
      
      if (tokens.length === 0) {
        console.log('No FCM tokens found for recipient');
        return null;
      }
      
      // Prepare notification message
      const replyContent = reply.content || '';
      const replyPreview = replyContent.length > 50 
        ? replyContent.substring(0, 50) + '...' 
        : replyContent;
      
      const message = {
        data: {
          type: 'storyReply',
          storyId: storyId,
          replierId: replierId,
          replierUsername: replierUsername,
          replyContent: replyPreview,
          timestamp: Date.now().toString(),
        },
        notification: {
          title: 'New story reply',
          body: `${replierUsername} replied to your story: ${replyPreview}`,
        },
        tokens: tokens,
      };
      
      // Send notification
      const response = await admin.messaging().sendMulticast(message);
      console.log(`Story reply notification sent: ${response.successCount} successful, ${response.failureCount} failed`);
      
      // Create notification document
      await admin.firestore()
        .collection('users')
        .doc(authorId)
        .collection('notifications')
        .add({
          type: 'storyReply',
          fromUserId: replierId,
          fromUsername: replierUsername,
          storyId: storyId,
          replyContent: replyPreview,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      
    } catch (error) {
      console.error('Error sending story reply notification:', error);
    }
  }
);

/**
 * Cloud Function: Auto-escalate high-priority reports
 * Triggered when a new report is created
 */
exports.onReportCreated = onDocumentCreated(
  'reports/{reportId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data associated with the event');
      return null;
    }

    try {
      const reportData = snap.data();

      // Check if report is high priority (violence, harassment)
      const highPriorityCategories = ['violence', 'harassment'];
      const category = reportData.reportCategory;

      if (highPriorityCategories.includes(category)) {
        // Get admin users to notify
        const adminSnapshot = await admin.firestore()
          .collection('users')
          .where('isAdmin', '==', true)
          .limit(10)
          .get();

        if (adminSnapshot.empty) {
          console.log('No admin users found to notify');
          return;
        }

        // Send notification to admins (can be enhanced with FCM)
        console.log(`High-priority report created: ${event.params.reportId}, Category: ${category}`);
        
        // TODO: Send FCM notification to admins if needed
        // For now, just log it. Admins will see it in the dashboard.
      }
    } catch (error) {
      console.error('Error processing report:', error);
    }
  }
);

/**
 * Cloud Function: Track boost impression (HTTPS Callable)
 * Called from client when a boosted post is viewed
 * 
 * Usage: Call from Flutter using FirebaseFunctions.instance.httpsCallable('trackBoostImpression')
 */
exports.trackBoostImpression = onCall(async (request) => {
  // Verify authentication
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { postId } = request.data;
  
  if (!postId) {
    throw new HttpsError(
      'invalid-argument',
      'postId is required'
    );
  }

  try {
    const postRef = admin.firestore().collection('posts').doc(postId);

    return await admin.firestore().runTransaction(async (transaction) => {
      const postDoc = await transaction.get(postRef);
      
      if (!postDoc.exists) {
        throw new HttpsError(
          'not-found',
          'Post not found'
        );
      }

      const postData = postDoc.data();
      
      if (!postData.isBoosted) {
        throw new HttpsError(
          'failed-precondition',
          'Post is not boosted'
        );
      }

      // Check if boost has expired
      if (postData.boostEndTime) {
        const boostEndTime = postData.boostEndTime.toDate();
        if (boostEndTime < new Date()) {
          // Boost has expired, but don't throw error - just don't increment
          return { success: false, message: 'Boost has expired' };
        }
      }

      // Increment impressions atomically
      transaction.update(postRef, {
        'boostStats.impressions': admin.firestore.FieldValue.increment(1),
        'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true };
    });
  } catch (error) {
    console.error('Error tracking boost impression:', error);
    
    // If it's already an HttpsError, rethrow it
    if (error instanceof HttpsError) {
      throw error;
    }
    
    // Otherwise, wrap it in an HttpsError
    throw new HttpsError(
      'internal',
      'Error tracking boost impression: ' + error.message
    );
  }
});

/**
 * Cloud Function: Track boost engagement (Firestore Trigger)
 * Triggered when a user reacts to a boosted post
 * Automatically increments boostStats.engagement
 */
exports.trackBoostEngagement = onDocumentCreated(
  'posts/{postId}/reactions/{userId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data associated with the event');
      return null;
    }

    try {
      const postId = event.params.postId;
      const postRef = admin.firestore().collection('posts').doc(postId);

      const postDoc = await postRef.get();
      
      if (!postDoc.exists) {
        console.log('Post not found');
        return null;
      }

      const postData = postDoc.data();
      
      // Only track if post is boosted
      if (!postData.isBoosted) {
        console.log('Post is not boosted, skipping engagement tracking');
        return null;
      }

      // Check if boost has expired
      if (postData.boostEndTime) {
        const boostEndTime = postData.boostEndTime.toDate();
        if (boostEndTime < new Date()) {
          console.log('Boost has expired, skipping engagement tracking');
          return null;
        }
      }

      // Increment engagement count
      await postRef.update({
        'boostStats.engagement': admin.firestore.FieldValue.increment(1),
        'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Tracked boost engagement for post ${postId}`);
      return null;
    } catch (error) {
      console.error('Error tracking boost engagement:', error);
      return null;
    }
  }
);

/**
 * Phase 2: Calculate contentWeight based on post type
 * Uses contentType enum or infers from media/link fields
 */
function calculateContentWeight(postData) {
  // Check if contentType is explicitly set
  if (postData.contentType) {
    const contentType = postData.contentType.toLowerCase();
    switch (contentType) {
      case 'text': return 1.0;
      case 'image': return 1.2;
      case 'video': return 1.5;
      case 'link': return 1.3;
      case 'poll': return 1.1;
      case 'mixed': return 1.4;
      default: return 1.0;
    }
  }
  
  // Infer from mediaItems or legacy mediaUrls
  const mediaItems = postData.mediaItems || [];
  const mediaUrls = postData.mediaUrls || [];
  const hasLink = postData.linkPreview != null;
  
  // Check for video and image in mediaItems
  let hasVideo = false;
  let hasImage = false;
  
  if (mediaItems.length > 0) {
    hasVideo = mediaItems.some(item => 
      item.type === 'video' || 
      item.url?.includes('.mp4') || 
      item.url?.includes('.mov')
    );
    hasImage = mediaItems.some(item => 
      item.type === 'image' || 
      item.url?.includes('.jpg') || 
      item.url?.includes('.png') ||
      item.url?.includes('.jpeg')
    );
  } else if (mediaUrls.length > 0) {
    // Legacy format
    hasVideo = mediaUrls.some(url => 
      url.includes('.mp4') || url.includes('.mov')
    );
    hasImage = mediaUrls.some(url => 
      url.includes('.jpg') || url.includes('.png') || url.includes('.jpeg')
    );
  }
  
  // Determine weight
  if (hasLink) return 1.3; // Link
  if (hasVideo && hasImage) return 1.4; // Mixed
  if (hasVideo) return 1.5; // Video
  if (hasImage) return 1.2; // Image
  return 1.0; // Text
}

/**
 * Phase 2: Infer contentType from post data
 */
function inferContentType(postData) {
  const mediaItems = postData.mediaItems || [];
  const mediaUrls = postData.mediaUrls || [];
  const hasLink = postData.linkPreview != null;
  
  let hasVideo = false;
  let hasImage = false;
  
  if (mediaItems.length > 0) {
    hasVideo = mediaItems.some(item => 
      item.type === 'video' || 
      item.url?.includes('.mp4') || 
      item.url?.includes('.mov')
    );
    hasImage = mediaItems.some(item => 
      item.type === 'image' || 
      item.url?.includes('.jpg') || 
      item.url?.includes('.png')
    );
  } else if (mediaUrls.length > 0) {
    hasVideo = mediaUrls.some(url => url.includes('.mp4') || url.includes('.mov'));
    hasImage = mediaUrls.some(url => url.includes('.jpg') || url.includes('.png'));
  }
  
  if (hasLink) return 'link';
  if (hasVideo && hasImage) return 'mixed';
  if (hasVideo) return 'video';
  if (hasImage) return 'image';
  return 'text';
}

/**
 * Phase 2: Get all followers (friends + page followers)
 */
async function getFollowers(authorId, pageId) {
  const followers = new Set();
  
  // Get friends (if user post)
  if (!pageId) {
    try {
      const authorDoc = await admin.firestore()
        .collection('users')
        .doc(authorId)
        .get();
      
      if (authorDoc.exists) {
        const friends = authorDoc.data()?.friends || [];
        friends.forEach(friendId => {
          if (friendId && friendId !== authorId) {
            followers.add(friendId);
          }
        });
      }
    } catch (error) {
      console.error(`Error getting friends for ${authorId}:`, error);
    }
  }
  
  // Get page followers (if page post)
  if (pageId) {
    try {
      // Get users who have this page in their followedPages array
      // Query users collection where followedPages array contains pageId
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .where('followedPages', 'array-contains', pageId)
        .limit(1000) // Adjust based on your needs
        .get();
      
      usersSnapshot.docs.forEach(doc => {
        const userId = doc.id;
        if (userId && userId !== authorId) {
          followers.add(userId);
        }
      });
      
      console.log(`Found ${usersSnapshot.size} page followers for page ${pageId}`);
    } catch (error) {
      console.error(`Error getting page followers for ${pageId}:`, error);
    }
  }
  
  return Array.from(followers);
}

/**
 * Phase 2: Fan-out post to a batch of followers
 */
async function fanOutToFollowers(
  postId,
  authorId,
  pageId,
  contentWeight,
  followerIds
) {
  if (followerIds.length === 0) return;
  
  const batch = admin.firestore().batch();
  const now = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days
  );
  
  const targetId = pageId || authorId;
  const postRef = admin.firestore().collection('posts').doc(postId);
  
  // Get affinities for all followers in parallel
  const affinityPromises = followerIds.map(async (followerId) => {
    try {
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(followerId)
        .get();
      
      if (!userDoc.exists) {
        return { followerId, affinity: 1.0 };
      }
      
      const userData = userDoc.data();
      const affinities = userData?.userAffinities || {};
      const affinity = affinities[targetId] ?? 1.0;
      
      return { followerId, affinity };
    } catch (error) {
      console.error(`Error getting affinity for follower ${followerId}:`, error);
      return { followerId, affinity: 1.0 };
    }
  });
  
  const affinities = await Promise.all(affinityPromises);
  
  // Create personalized feed entries
  affinities.forEach(({ followerId, affinity }) => {
    const timeDecay = 1.0; // Always 1.0 at creation
    const score = affinity * contentWeight * timeDecay;
    
    const feedRef = admin.firestore()
      .collection('users')
      .doc(followerId)
      .collection('personalizedFeed')
      .doc(postId);
    
    batch.set(feedRef, {
      postId,
      authorId,
      pageId: pageId || null,
      score,
      calculatedAt: now,
      expiresAt,
      postRef: postRef,
      contentWeight,
      affinityScore: affinity,
      timeDecayMultiplier: timeDecay,
    });
  });
  
  await batch.commit();
  console.log(`Fan-out completed for ${followerIds.length} followers`);
}

/**
 * Phase 2: Update affinity score atomically (Client-Side Ranking Plan)
 * Updates userAffinities map with increment, clamped between 0.1 and 10.0
 * Implements LRU eviction to maintain 200-entry limit
 */
async function updateAffinity(userId, targetId, increment) {
  const userRef = admin.firestore().collection('users').doc(userId);
  
  return admin.firestore().runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    if (!userDoc.exists) {
      console.log(`User ${userId} not found for affinity update`);
      return;
    }
    
    const userData = userDoc.data();
    const affinities = userData.userAffinities || {};
    const currentAffinity = affinities[targetId] ?? 1.0;
    
    // Calculate new affinity and clamp between 0.1 and 10.0
    const newAffinity = Math.max(0.1, Math.min(10.0, currentAffinity + increment));
    
    // Enforce max 200 entries (LRU eviction if needed)
    const updatedAffinities = { ...affinities };
    updatedAffinities[targetId] = newAffinity;
    
    if (Object.keys(updatedAffinities).length > 200) {
      // Remove lowest affinity entry (LRU eviction)
      const sorted = Object.entries(updatedAffinities)
        .sort((a, b) => a[1] - b[1]);
      delete updatedAffinities[sorted[0][0]];
      console.log(`LRU eviction: Removed lowest affinity entry for user ${userId}`);
    }
    
    transaction.update(userRef, {
      userAffinities: updatedAffinities,
    });
  });
}

/**
 * Phase 2: Recalculate feed scores for posts from a specific author/page
 */
async function recalculateFeedScores(userId, targetId) {
  try {
    // Get user's current affinity for this target first
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    if (!userDoc.exists) {
      return;
    }
    
    const userData = userDoc.data();
    const affinities = userData.userAffinities || {};
    const affinity = affinities[targetId] ?? 1.0;
    
    // Get all posts from this target in user's personalized feed
    // Query by authorId (for user posts) or pageId (for page posts)
    const feedSnapshotByAuthor = await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('personalizedFeed')
      .where('authorId', '==', targetId)
      .get();
    
    const feedSnapshotByPage = await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('personalizedFeed')
      .where('pageId', '==', targetId)
      .get();
    
    // Combine results and deduplicate
    const allFeedDocs = new Map();
    feedSnapshotByAuthor.docs.forEach(doc => {
      allFeedDocs.set(doc.id, doc);
    });
    feedSnapshotByPage.docs.forEach(doc => {
      allFeedDocs.set(doc.id, doc);
    });
    
    if (allFeedDocs.size === 0) {
      return; // No posts to recalculate
    }
    
    // Recalculate scores for all posts
    const now = admin.firestore.Timestamp.now();
    let batchCount = 0;
    let batch = admin.firestore().batch();
    
    for (const feedDoc of allFeedDocs.values()) {
      const feedData = feedDoc.data();
      const contentWeight = feedData.contentWeight || 1.0;
      const calculatedAt = feedData.calculatedAt;
      
      // Calculate time decay
      const timeDecay = calculateTimeDecay(calculatedAt);
      
      const newScore = affinity * contentWeight * timeDecay;
      
      batch.update(feedDoc.ref, {
        score: newScore,
        affinityScore: affinity,
        timeDecayMultiplier: timeDecay,
        calculatedAt: now,
      });
      
      batchCount++;
      
      // Firestore batch limit is 500 - commit and start new batch
      if (batchCount >= 500) {
        await batch.commit();
        batch = admin.firestore().batch();
        batchCount = 0;
      }
    }
    
    // Commit remaining updates
    if (batchCount > 0) {
      await batch.commit();
    }
    
    console.log(`Recalculated ${allFeedDocs.size} feed scores for user ${userId}, target ${targetId}`);
  } catch (error) {
    console.error(`Error recalculating feed scores for user ${userId}, target ${targetId}:`, error);
  }
}

/**
 * Phase 2: Calculate time decay using exponential decay formula
 */
function calculateTimeDecay(calculatedAtTimestamp) {
  if (!calculatedAtTimestamp) {
    return 1.0; // No decay if timestamp is missing
  }
  
  const now = Date.now();
  const calculatedAt = calculatedAtTimestamp.toMillis();
  const hoursSinceCreation = (now - calculatedAt) / (1000 * 60 * 60);
  
  // Exponential decay: e^(-0.1 * hours)
  // After 24 hours: ~0.08
  // After 48 hours: ~0.006
  // After 72 hours: ~0.0005
  return Math.exp(-0.1 * hoursSinceCreation);
}

/**
 * Phase 2: Recalculate time decay for all personalized feeds (Scheduled)
 * Runs every 1 hour to update time decay multipliers
 */
exports.recalculateTimeDecay = onSchedule({
  schedule: 'every 1 hours',
  timeZone: 'UTC',
}, async (event) => {
  try {
    console.log('Starting time decay recalculation...');
    
    // Get all users (or sample if too many - process in batches)
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .limit(1000) // Process 1000 users per run
      .get();
    
    let totalProcessed = 0;
    let totalUpdated = 0;
    
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      
      try {
        // Get all feed entries for this user
        const feedSnapshot = await admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('personalizedFeed')
          .get();
        
        if (feedSnapshot.empty) {
          continue;
        }
        
        const batch = admin.firestore().batch();
        let batchCount = 0;
        
        feedSnapshot.docs.forEach((feedDoc) => {
          const feedData = feedDoc.data();
          const affinityScore = feedData.affinityScore || 1.0;
          const contentWeight = feedData.contentWeight || 1.0;
          const calculatedAt = feedData.calculatedAt;
          
          const timeDecay = calculateTimeDecay(calculatedAt);
          const newScore = affinityScore * contentWeight * timeDecay;
          
          batch.update(feedDoc.ref, {
            score: newScore,
            timeDecayMultiplier: timeDecay,
          });
          
          batchCount++;
          totalUpdated++;
          
          // Firestore batch limit is 500
          if (batchCount >= 500) {
            batch.commit();
            batchCount = 0;
          }
        });
        
        if (batchCount > 0) {
          await batch.commit();
        }
        
        totalProcessed++;
      } catch (userError) {
        console.error(`Error processing user ${userId}:`, userError);
        // Continue with next user
      }
    }
    
    console.log(`Time decay recalculation complete. Processed ${totalProcessed} users, updated ${totalUpdated} feed entries`);
    return null;
  } catch (error) {
    console.error('Error in recalculateTimeDecay:', error);
    return null;
  }
});

/**
 * Phase 2: Cleanup expired feed entries (Scheduled)
 * Runs every 24 hours to remove feed entries older than 30 days
 */
exports.cleanupExpiredFeedEntries = onSchedule({
  schedule: 'every 24 hours',
  timeZone: 'UTC',
}, async (event) => {
  try {
    console.log('Starting cleanup of expired feed entries...');
    
    const now = admin.firestore.Timestamp.now();
    let totalDeleted = 0;
    
    // Get all users (or process in batches)
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .limit(1000) // Process 1000 users per run
      .get();
    
    for (const userDoc of usersSnapshot.docs) {
      try {
        const expiredEntries = await admin.firestore()
          .collection('users')
          .doc(userDoc.id)
          .collection('personalizedFeed')
          .where('expiresAt', '<=', now)
          .get();
        
        if (expiredEntries.empty) {
          continue;
        }
        
        // Batch delete (Firestore batch limit is 500)
        const batches = [];
        for (let i = 0; i < expiredEntries.docs.length; i += 500) {
          const batch = admin.firestore().batch();
          const batchDocs = expiredEntries.docs.slice(i, i + 500);
          
          batchDocs.forEach(doc => batch.delete(doc.ref));
          batches.push(batch.commit());
          
          totalDeleted += batchDocs.length;
        }
        
        await Promise.all(batches);
      } catch (userError) {
        console.error(`Error cleaning up feed for user ${userDoc.id}:`, userError);
        // Continue with next user
      }
    }
    
    console.log(`Cleanup complete. Deleted ${totalDeleted} expired feed entries`);
    return null;
  } catch (error) {
    console.error('Error in cleanupExpiredFeedEntries:', error);
    return null;
  }
});

/**
 * Client-Side Ranking Plan: Update affinity when user likes a post
 * Triggered when a reaction is created in posts/{postId}/reactions/{userId}
 * This is a standalone function for the Client-Side Ranking approach
 */
exports.onUserInteraction = onDocumentCreated(
  'posts/{postId}/reactions/{userId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data associated with the event');
      return null;
    }
    
    try {
      const postId = event.params.postId;
      const userId = event.params.userId; // User who liked
      
      // Get post to find author
      const postDoc = await admin.firestore()
        .collection('posts')
        .doc(postId)
        .get();
      
      if (!postDoc.exists) {
        console.log('Post not found');
        return null;
      }
      
      const postData = postDoc.data();
      const postAuthorId = postData.authorId;
      const postPageId = postData.pageId || null;
      
      // Don't update affinity if user interacts with own post
      if (userId === postAuthorId) {
        console.log('User liked own post, skipping affinity update');
        return null;
      }
      
      // Target is pageId (if page post) or authorId (if user post)
      const targetId = postPageId || postAuthorId;
      
      // Update affinity atomically (+0.5 for like)
      await updateAffinity(userId, targetId, 0.5);
      
      console.log(`Updated affinity for user ${userId} -> ${targetId} (like): +0.5`);
      return null;
    } catch (error) {
      console.error('Error updating affinity on like:', error);
      return null;
    }
  }
);

/**
 * Client-Side Ranking Plan: Update affinity when user comments on a post
 * Triggered when a comment is created in posts/{postId}/comments/{commentId}
 * This is a standalone function for the Client-Side Ranking approach
 */
exports.onUserInteractionComment = onDocumentCreated(
  'posts/{postId}/comments/{commentId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data associated with the event');
      return null;
    }
    
    try {
      const commentData = snap.data();
      const userId = commentData.userId; // User who commented
      const postId = event.params.postId;
      
      if (!userId) {
        console.log('Comment missing userId');
        return null;
      }
      
      // Get post to find author
      const postDoc = await admin.firestore()
        .collection('posts')
        .doc(postId)
        .get();
      
      if (!postDoc.exists) {
        console.log('Post not found');
        return null;
      }
      
      const postData = postDoc.data();
      const postAuthorId = postData.authorId;
      const postPageId = postData.pageId || null;
      
      // Don't update affinity if user comments on own post
      if (userId === postAuthorId) {
        console.log('User commented on own post, skipping affinity update');
        return null;
      }
      
      // Target is pageId (if page post) or authorId (if user post)
      const targetId = postPageId || postAuthorId;
      
      // Update affinity atomically (+1.0 for comment - worth more than like)
      await updateAffinity(userId, targetId, 1.0);
      
      console.log(`Updated affinity for user ${userId} -> ${targetId} (comment): +1.0`);
      return null;
    } catch (error) {
      console.error('Error updating affinity on comment:', error);
      return null;
    }
  }
);

/**
 * Cloud Function: Cleanup expired boosts (Scheduled)
 * Runs every 24 hours to automatically disable expired boosts
 * 
 * This ensures data consistency - expired boosts are marked as inactive
 */
exports.cleanupExpiredBoosts = onSchedule({
  schedule: 'every 24 hours',
  timeZone: 'UTC',
}, async (event) => {
  try {
    const now = admin.firestore.Timestamp.now();
    const postsRef = admin.firestore().collection('posts');

    // Query for expired boosts
    // Note: Firestore doesn't support multiple range queries on different fields,
    // so we'll query for all active boosts and filter client-side
    const activeBoostsSnapshot = await postsRef
      .where('isBoosted', '==', true)
      .limit(500)
      .get();

    if (activeBoostsSnapshot.empty) {
      console.log('No active boosts found');
      return null;
    }

    const expiredPosts = [];
    activeBoostsSnapshot.docs.forEach((doc) => {
      const postData = doc.data();
      const boostEndTime = postData.boostEndTime;

      if (boostEndTime && boostEndTime <= now) {
        expiredPosts.push(doc.ref);
      }
    });

    if (expiredPosts.length === 0) {
      console.log('No expired boosts found');
      return null;
    }

    // Batch update expired boosts (Firestore batch limit is 500)
    const batches = [];
    for (let i = 0; i < expiredPosts.length; i += 500) {
      const batch = admin.firestore().batch();
      const batchPosts = expiredPosts.slice(i, i + 500);

      batchPosts.forEach((postRef) => {
        batch.update(postRef, {
          'isBoosted': false,
          'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      batches.push(batch.commit());
    }

    await Promise.all(batches);

    console.log(`Cleaned up ${expiredPosts.length} expired boosts`);
    return null;
  } catch (error) {
    console.error('Error cleaning up expired boosts:', error);
    return null;
  }
});
