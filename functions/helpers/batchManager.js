// functions/helpers/batchManager.js
// Batch Management for Notification Grouping

const admin = require('firebase-admin');

/**
 * Get batching window duration based on interaction type
 * @param {string} interactionType - 'like', 'comment', or 'mention'
 * @returns {number} Duration in milliseconds
 */
function getBatchingWindow(interactionType) {
  const windows = {
    like: 60000,      // 1 minute for likes
    comment: 30000,   // 30 seconds for comments
    mention: 10000    // 10 seconds for mentions
  };
  return windows[interactionType] || 60000;
}

/**
 * Get or create a batch for an interaction
 * @param {string} contentType - 'post' or 'reel'
 * @param {string} contentId - ID of the post or reel
 * @param {string} authorId - ID of the content creator
 * @param {string} interactionType - 'like', 'comment', or 'mention'
 * @returns {Promise<FirebaseFirestore.DocumentSnapshot>} Batch document
 */
async function getOrCreateBatch(contentType, contentId, authorId, interactionType) {
  try {
    // Check for existing pending batch
    const batchQuery = await admin.firestore()
      .collection('notificationBatches')
      .where('contentType', '==', contentType)
      .where('contentId', '==', contentId)
      .where('interactionType', '==', interactionType)
      .where('status', '==', 'pending')
      .limit(1)
      .get();

    if (!batchQuery.empty) {
      console.log(`Found existing batch for ${contentType} ${contentId}`);
      return batchQuery.docs[0];
    }

    // Create new batch
    const batchRef = admin.firestore().collection('notificationBatches').doc();
    const scheduledFor = new Date(Date.now() + getBatchingWindow(interactionType));

    await batchRef.set({
      batchId: batchRef.id,
      contentType,
      contentId,
      authorId,
      interactionType,
      interactions: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      scheduledFor,
      status: 'pending',
      sentAt: null
    });

    console.log(`Created new batch ${batchRef.id} for ${contentType} ${contentId}, scheduled for ${scheduledFor.toISOString()}`);

    return await batchRef.get();
  } catch (error) {
    console.error('Error in getOrCreateBatch:', error);
    throw error;
  }
}

/**
 * Add interaction to an existing batch
 * @param {string} batchId - ID of the batch
 * @param {object} interaction - Interaction data
 * @returns {Promise<void>}
 */
async function addInteractionToBatch(batchId, interaction) {
  try {
    const batchRef = admin.firestore()
      .collection('notificationBatches')
      .doc(batchId);

    // Get current batch to check interaction type
    const batchDoc = await batchRef.get();
    if (!batchDoc.exists) {
      throw new Error(`Batch ${batchId} not found`);
    }

    const batchData = batchDoc.data();

    // Reset scheduled time to extend batching window
    const newScheduledFor = new Date(Date.now() + getBatchingWindow(batchData.interactionType));

    await batchRef.update({
      interactions: admin.firestore.FieldValue.arrayUnion(interaction),
      scheduledFor: newScheduledFor
    });

    console.log(`Added interaction from ${interaction.username} to batch ${batchId}, rescheduled for ${newScheduledFor.toISOString()}`);
  } catch (error) {
    console.error('Error in addInteractionToBatch:', error);
    throw error;
  }
}

/**
 * Check if interaction should be batched or sent immediately
 * @param {object} contentData - Post or reel data
 * @param {string} interactionType - 'like', 'comment', or 'mention'
 * @returns {boolean} True if should batch, false if should send immediately
 */
function shouldBatchInteraction(contentData, interactionType, authorPreferences = {}) {
  // Check user preference
  if (authorPreferences.batchingEnabled === false) {
    return false;
  }

  // First interaction? Send immediately
  if (interactionType === 'like' && contentData.likeCount === 1) {
    return false;
  }
  if (interactionType === 'comment' && contentData.commentCount === 1) {
    return false;
  }

  // Milestone likes? Send immediately
  const milestones = [10, 50, 100, 500, 1000];
  if (interactionType === 'like' && milestones.includes(contentData.likeCount)) {
    return false;
  }

  // Otherwise, batch it
  return true;
}

module.exports = {
  getBatchingWindow,
  getOrCreateBatch,
  addInteractionToBatch,
  shouldBatchInteraction
};
