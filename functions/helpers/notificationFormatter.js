// functions/helpers/notificationFormatter.js
// Notification Formatting for Grouped Notifications

/**
 * Format grouped notification message
 * @param {object} batch - Batch document data
 * @returns {object|null} Formatted notification or null
 */
function formatGroupedNotification(batch) {
    const interactions = batch.interactions || [];
    const count = interactions.length;
    const type = batch.interactionType;
    const contentType = batch.contentType;

    if (count === 0) {
        console.warn('formatGroupedNotification: No interactions in batch');
        return null;
    }

    // Single interaction
    if (count === 1) {
        return formatSingleNotification(interactions[0], type, contentType, batch);
    }

    // Two interactions
    if (count === 2) {
        const names = interactions.map(i => i.username).join(' and ');
        return {
            title: `${names} ${getActionText(type, count)} your ${contentType}`,
            body: getContentPreview(batch, interactions),
            data: {
                type: `${contentType}${capitalize(type)}`,
                contentId: batch.contentId,
                interactors: interactions.map(i => i.userId).join(','),
                count: count.toString(),
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            }
        };
    }

    // Multiple interactions (3+)
    const firstName = interactions[0].username;
    const othersCount = count - 1;
    return {
        title: `${firstName} and ${othersCount} other${othersCount > 1 ? 's' : ''} ${getActionText(type, count)} your ${contentType}`,
        body: getContentPreview(batch, interactions),
        data: {
            type: `${contentType}${capitalize(type)}`,
            contentId: batch.contentId,
            interactors: interactions.map(i => i.userId).join(','),
            count: count.toString(),
            click_action: 'FLUTTER_NOTIFICATION_CLICK'
        }
    };
}

/**
 * Format single interaction notification
 * @param {object} interaction - Interaction data
 * @param {string} type - Interaction type
 * @param {string} contentType - Content type
 * @param {object} batch - Batch data
 * @returns {object} Formatted notification
 */
function formatSingleNotification(interaction, type, contentType, batch) {
    const username = interaction.username || 'Someone';

    if (type === 'like') {
        return {
            title: `${username} liked your ${contentType}`,
            body: getContentPreview(batch, [interaction]),
            data: {
                type: `${contentType}Like`,
                contentId: batch.contentId,
                fromUserId: interaction.userId,
                fromUsername: username,
                fromPhotoUrl: interaction.photoUrl || '',
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            }
        };
    }

    if (type === 'comment') {
        const commentText = interaction.data?.text || 'commented on your post';
        return {
            title: `${username} commented on your ${contentType}`,
            body: commentText.length > 100 ? commentText.substring(0, 100) + '...' : commentText,
            data: {
                type: `${contentType}Comment`,
                contentId: batch.contentId,
                commentId: interaction.data?.commentId || '',
                fromUserId: interaction.userId,
                fromUsername: username,
                fromPhotoUrl: interaction.photoUrl || '',
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            }
        };
    }

    if (type === 'mention') {
        return {
            title: `${username} mentioned you in a ${contentType}`,
            body: getContentPreview(batch, [interaction]),
            data: {
                type: `${contentType}Mention`,
                contentId: batch.contentId,
                fromUserId: interaction.userId,
                fromUsername: username,
                fromPhotoUrl: interaction.photoUrl || '',
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            }
        };
    }

    // Fallback
    return {
        title: `${username} interacted with your ${contentType}`,
        body: 'Tap to view',
        data: {
            type: `${contentType}Interaction`,
            contentId: batch.contentId,
            fromUserId: interaction.userId,
            click_action: 'FLUTTER_NOTIFICATION_CLICK'
        }
    };
}

/**
 * Get action text for notification
 * @param {string} type - Interaction type
 * @param {number} count - Number of interactions
 * @returns {string} Action text
 */
function getActionText(type, count) {
    const actions = {
        like: 'liked',
        comment: 'commented on',
        mention: 'mentioned you in'
    };
    return actions[type] || 'interacted with';
}

/**
 * Get content preview for notification body
 * @param {object} batch - Batch data
 * @param {array} interactions - Interaction array
 * @returns {string} Preview text
 */
function getContentPreview(batch, interactions) {
    const type = batch.interactionType;
    const count = interactions.length;

    if (type === 'comment' && count === 1) {
        const commentText = interactions[0].data?.text || '';
        return commentText.length > 100 ? commentText.substring(0, 100) + '...' : commentText;
    }

    if (type === 'comment' && count > 1) {
        return `${count} people commented on your ${batch.contentType}`;
    }

    if (type === 'like') {
        return count === 1
            ? `Your ${batch.contentType}`
            : `${count} people liked your ${batch.contentType}`;
    }

    return `Tap to view your ${batch.contentType}`;
}

/**
 * Capitalize first letter of string
 * @param {string} str - String to capitalize
 * @returns {string} Capitalized string
 */
function capitalize(str) {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1);
}

/**
 * Check if notification should be deduplicated
 * @param {object} batch - Batch data
 * @param {object} lastSent - Last sent notification data
 * @returns {boolean} True if should skip (duplicate), false if should send
 */
function shouldDeduplicate(batch, lastSent) {
    if (!lastSent) return false;

    const timeSinceLastSent = Date.now() - lastSent.lastSentAt;
    const fiveMinutes = 300000;

    // Don't send if we just sent one less than 5 minutes ago
    if (timeSinceLastSent < fiveMinutes) {
        console.log(`Skipping duplicate notification (sent ${timeSinceLastSent}ms ago)`);
        return true;
    }

    return false;
}

module.exports = {
    formatGroupedNotification,
    formatSingleNotification,
    getActionText,
    getContentPreview,
    capitalize,
    shouldDeduplicate
};
