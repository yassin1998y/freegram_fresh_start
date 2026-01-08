// functions/helpers/rateLimiter.js
// Rate Limiting for Notification Spam Prevention

const admin = require('firebase-admin');

/**
 * Rate limit configuration
 */
const RATE_LIMITS = {
    reaction: {
        maxPerHour: 10,      // Max 10 likes per content per hour
        maxPerDay: 50        // Max 50 likes per content per day
    },
    comment: {
        maxPerMinute: 3,     // Max 3 comments per minute
        maxPerHour: 20,      // Max 20 comments per hour
        maxPerDay: 100       // Max 100 comments per day
    }
};

/**
 * Check if user has exceeded rate limit
 * @param {string} userId - ID of the user performing the action
 * @param {string} contentId - ID of the content (post or reel)
 * @param {string} interactionType - 'reaction' or 'comment'
 * @returns {Promise<boolean>} True if within limits, false if exceeded
 */
async function checkRateLimit(userId, contentId, interactionType) {
    try {
        const limitDocId = `${userId}_${contentId}`;
        const limitDoc = await admin.firestore()
            .collection('userInteractionLimits')
            .doc(limitDocId)
            .get();

        if (!limitDoc.exists) {
            // No limits recorded yet, allow
            return true;
        }

        const data = limitDoc.data();
        const limits = data[interactionType + 's'] || {};
        const now = Date.now();

        // Get rate limit config
        const config = RATE_LIMITS[interactionType];
        if (!config) {
            console.warn(`No rate limit config for ${interactionType}`);
            return true;
        }

        // Check minute limit (for comments)
        if (config.maxPerMinute) {
            const minuteInMs = 60000;
            if (now - limits.lastAt < minuteInMs) {
                if (limits.minuteCount >= config.maxPerMinute) {
                    console.log(`Rate limit exceeded: ${userId} hit minute limit on ${contentId}`);
                    return false;
                }
            }
        }

        // Check hourly limit
        const hourInMs = 3600000;
        if (now - limits.windowStart < hourInMs) {
            if (limits.count >= config.maxPerHour) {
                console.log(`Rate limit exceeded: ${userId} hit hourly limit on ${contentId}`);
                return false;
            }
        }

        // Check daily limit
        const dayInMs = 86400000;
        if (now - limits.dayWindowStart < dayInMs) {
            if (limits.dayCount >= config.maxPerDay) {
                console.log(`Rate limit exceeded: ${userId} hit daily limit on ${contentId}`);
                return false;
            }
        }

        return true;
    } catch (error) {
        console.error('Error in checkRateLimit:', error);
        // On error, allow the action (fail open)
        return true;
    }
}

/**
 * Record interaction for rate limiting
 * @param {string} userId - ID of the user performing the action
 * @param {string} contentId - ID of the content (post or reel)
 * @param {string} interactionType - 'reaction' or 'comment'
 * @returns {Promise<void>}
 */
async function recordInteraction(userId, contentId, interactionType) {
    try {
        const limitDocId = `${userId}_${contentId}`;
        const docRef = admin.firestore()
            .collection('userInteractionLimits')
            .doc(limitDocId);

        const doc = await docRef.get();
        const now = Date.now();
        const hourInMs = 3600000;
        const dayInMs = 86400000;
        const minuteInMs = 60000;

        if (!doc.exists) {
            // Create new limit document
            await docRef.set({
                userId,
                contentId,
                [interactionType + 's']: {
                    count: 1,
                    minuteCount: 1,
                    dayCount: 1,
                    lastAt: now,
                    windowStart: now,
                    dayWindowStart: now
                }
            });
            console.log(`Created rate limit tracking for ${userId} on ${contentId}`);
            return;
        }

        const data = doc.data();
        const limits = data[interactionType + 's'] || {};

        // Reset windows if time has passed
        const resetHourWindow = now - limits.windowStart >= hourInMs;
        const resetDayWindow = now - limits.dayWindowStart >= dayInMs;
        const resetMinuteWindow = now - limits.lastAt >= minuteInMs;

        await docRef.update({
            [interactionType + 's']: {
                count: resetHourWindow ? 1 : limits.count + 1,
                minuteCount: resetMinuteWindow ? 1 : (limits.minuteCount || 0) + 1,
                dayCount: resetDayWindow ? 1 : (limits.dayCount || 0) + 1,
                lastAt: now,
                windowStart: resetHourWindow ? now : limits.windowStart,
                dayWindowStart: resetDayWindow ? now : (limits.dayWindowStart || now)
            }
        });

        console.log(`Recorded ${interactionType} for ${userId} on ${contentId}`);
    } catch (error) {
        console.error('Error in recordInteraction:', error);
        // Don't throw - rate limiting is not critical
    }
}

/**
 * Get remaining rate limit for a user
 * @param {string} userId - ID of the user
 * @param {string} contentId - ID of the content
 * @param {string} interactionType - 'reaction' or 'comment'
 * @returns {Promise<object>} Remaining limits
 */
async function getRemainingLimit(userId, contentId, interactionType) {
    try {
        const limitDocId = `${userId}_${contentId}`;
        const limitDoc = await admin.firestore()
            .collection('userInteractionLimits')
            .doc(limitDocId)
            .get();

        if (!limitDoc.exists) {
            const config = RATE_LIMITS[interactionType];
            return {
                hourly: config.maxPerHour,
                daily: config.maxPerDay
            };
        }

        const data = limitDoc.data();
        const limits = data[interactionType + 's'] || {};
        const config = RATE_LIMITS[interactionType];
        const now = Date.now();
        const hourInMs = 3600000;
        const dayInMs = 86400000;

        const hourlyRemaining = now - limits.windowStart >= hourInMs
            ? config.maxPerHour
            : config.maxPerHour - limits.count;

        const dailyRemaining = now - limits.dayWindowStart >= dayInMs
            ? config.maxPerDay
            : config.maxPerDay - (limits.dayCount || 0);

        return {
            hourly: Math.max(0, hourlyRemaining),
            daily: Math.max(0, dailyRemaining)
        };
    } catch (error) {
        console.error('Error in getRemainingLimit:', error);
        return { hourly: 0, daily: 0 };
    }
}

module.exports = {
    checkRateLimit,
    recordInteraction,
    getRemainingLimit,
    RATE_LIMITS
};
