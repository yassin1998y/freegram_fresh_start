# Testing Boost Post Cloud Functions - Complete Guide

## ✅ Deployment Status

All three boost functions are **successfully deployed**:

1. ✅ **trackBoostImpression** - Callable function (HTTPS)
2. ✅ **trackBoostEngagement** - Firestore trigger (automatic)
3. ✅ **cleanupExpiredBoosts** - Scheduled function (runs every 24 hours)

---

## Test 1: trackBoostImpression (Callable Function)

### Status: ✅ DEPLOYED & READY
**Type:** HTTPS Callable  
**URL:** `https://us-central1-prototype-29c26.cloudfunctions.net/trackBoostImpression`

### How to Test:

#### Option A: From Flutter App (Recommended)
1. **Package Added:** `cloud_functions: ^4.7.7` added to `pubspec.yaml`
2. **Service Created:** `BoostAnalyticsService` created in `lib/services/boost_analytics_service.dart`
3. **Integration:** Already integrated in `PostCard` widget

**Automatic Test:**
- When you view a boosted post in the feed, it automatically calls `trackBoostImpression`
- Check logs: `firebase functions:log`

**Manual Test:**
```dart
final boostAnalytics = BoostAnalyticsService();
await boostAnalytics.trackBoostImpression('your-post-id');
```

#### Option B: Firebase Console
1. Go to: https://console.firebase.google.com/project/prototype-29c26/functions
2. Click on `trackBoostImpression`
3. Click "Test function" tab
4. Enter test data:
   ```json
   {
     "postId": "test-post-id-123"
   }
   ```
5. Click "Test the function"
6. Check response: `{"success": true}`

#### Option C: Test via cURL (requires auth token)
```bash
curl -X POST https://us-central1-prototype-29c26.cloudfunctions.net/trackBoostImpression \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
  -d '{"data":{"postId":"test-post-id"}}'
```

### Expected Behavior:
- ✅ Authenticated users can call the function
- ✅ Validates post exists and is boosted
- ✅ Atomically increments `boostStats.impressions`
- ✅ Returns `{"success": true}`

### Check Logs:
```bash
firebase functions:log | findstr trackBoostImpression
```

---

## Test 2: trackBoostEngagement (Firestore Trigger)

### Status: ✅ DEPLOYED & ACTIVE
**Type:** Firestore Trigger (onDocumentCreated)  
**Trigger Path:** `posts/{postId}/reactions/{userId}`

### How to Test:

#### From Flutter App:
1. **Create a boosted post** (or use existing boosted post)
2. **Like/react to the boosted post**
3. **Function automatically triggers**

**Steps:**
```dart
// 1. Boost a post first
await postRepository.boostPost(...);

// 2. Like the boosted post
await postRepository.likePost(postId, userId);

// 3. Function automatically triggers and increments boostStats.engagement
```

### Expected Behavior:
- ✅ Automatically triggers when reaction is created
- ✅ Checks if post is boosted
- ✅ Checks if boost hasn't expired
- ✅ Atomically increments `boostStats.engagement`
- ✅ Logs: "Tracked boost engagement for post {postId}"

### Check Logs:
```bash
firebase functions:log | findstr trackBoostEngagement
```

### Manual Test (via Firestore Console):
1. Go to Firestore Console
2. Navigate to: `posts/{postId}/reactions/{userId}`
3. Create a new reaction document
4. Function should trigger automatically
5. Check post document - `boostStats.engagement` should increment

---

## Test 3: cleanupExpiredBoosts (Scheduled Function)

### Status: ✅ DEPLOYED & SCHEDULED
**Type:** Scheduled (Cloud Scheduler)  
**Schedule:** Every 24 hours  
**Timezone:** UTC

### How to Test:

#### Option A: Wait for Scheduled Run
- Function runs automatically every 24 hours
- Check logs after 24 hours to verify execution

#### Option B: Manual Trigger (Google Cloud Console)
1. Go to: https://console.cloud.google.com/cloudscheduler?project=prototype-29c26
2. Find job: `cleanupExpiredBoosts`
3. Click "Run now" (three dots menu)
4. Check logs for execution

#### Option C: Create Test Data
1. Create a boosted post with `boostEndTime` in the past:
   ```dart
   await postRepository.boostPost(
     postId: 'test-post',
     userId: 'user-id',
     boostPackage: BoostPackageModel(...),
     targetingData: {},
   );
   
   // Manually set boostEndTime to past date in Firestore
   ```

2. Wait for scheduled run or trigger manually
3. Post should have `isBoosted = false` after cleanup

### Expected Behavior:
- ✅ Queries all posts where `isBoosted == true`
- ✅ Filters posts where `boostEndTime <= now`
- ✅ Sets `isBoosted = false` for expired boosts
- ✅ Batch updates (handles up to 500 at a time)
- ✅ Logs: "Cleaned up {count} expired boosts"

### Check Logs:
```bash
firebase functions:log | findstr cleanupExpiredBoosts
```

---

## View All Function Logs

```bash
# All logs
firebase functions:log

# Filter by function name
firebase functions:log | findstr trackBoostImpression
firebase functions:log | findstr trackBoostEngagement
firebase functions:log | findstr cleanupExpiredBoosts

# View in Firebase Console
# https://console.firebase.google.com/project/prototype-29c26/functions/logs
```

---

## Quick Test Checklist

### ✅ trackBoostImpression
- [ ] Function appears in Firebase Console
- [ ] Can call from Flutter app
- [ ] Logs show successful execution
- [ ] Post `boostStats.impressions` increments

### ✅ trackBoostEngagement
- [ ] Function appears in Firebase Console
- [ ] Reacting to boosted post triggers function
- [ ] Logs show "Tracked boost engagement"
- [ ] Post `boostStats.engagement` increments

### ✅ cleanupExpiredBoosts
- [ ] Function appears in Cloud Scheduler
- [ ] Scheduled job is active
- [ ] Can trigger manually from Cloud Console
- [ ] Logs show cleanup execution

---

## Troubleshooting

### Function not triggering?
1. Check function is deployed: `firebase functions:list`
2. Check logs: `firebase functions:log`
3. Verify Firestore rules allow updates
4. Check authentication (for callable functions)

### Errors in logs?
- Check function code syntax
- Verify Firestore document structure
- Check authentication tokens
- Review Cloud Scheduler configuration

---

## Integration Status

✅ **Cloud Functions:** Deployed  
✅ **Flutter Package:** Added (`cloud_functions: ^4.7.7`)  
✅ **Service Layer:** Created (`BoostAnalyticsService`)  
✅ **UI Integration:** Integrated in `PostCard`  
✅ **Security Rules:** Updated  

**All systems ready for testing!** 🚀
