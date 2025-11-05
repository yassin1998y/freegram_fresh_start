# Boost Post Cloud Functions - Testing Summary

## ✅ Deployment Status: ALL FUNCTIONS DEPLOYED

| Function | Type | Status | Location |
|----------|------|--------|----------|
| `trackBoostImpression` | Callable (HTTPS) | ✅ Active | us-central1 |
| `trackBoostEngagement` | Firestore Trigger | ✅ Active | us-central1 |
| `cleanupExpiredBoosts` | Scheduled (24h) | ✅ Active | us-central1 |

---

## Function 1: trackBoostImpression ✅

### Deployment Status
- ✅ Successfully deployed
- ✅ Appears in Firebase Console
- ✅ Flutter integration ready

### How to Test:

#### **Test 1: From Flutter App (Automatic)**
The function is already integrated in `PostCard` widget:
1. Open your app
2. Navigate to a boosted post
3. Function automatically calls when post is displayed
4. Check debug console: `✅ Boost impression tracked for post: {postId}`

#### **Test 2: Manual Call**
```dart
import 'package:freegram/services/boost_analytics_service.dart';

final analytics = BoostAnalyticsService();
await analytics.trackBoostImpression('your-post-id');
```

#### **Test 3: Firebase Console**
1. Go to: https://console.firebase.google.com/project/prototype-29c26/functions
2. Click `trackBoostImpression`
3. Click "Test function"
4. Enter: `{"postId": "test-post-id"}`
5. Click "Test the function"

### Expected Result:
- Success: `{"success": true}`
- Post document: `boostStats.impressions` increments by 1

### Check Logs:
```bash
firebase functions:log | findstr trackBoostImpression
```

---

## Function 2: trackBoostEngagement ✅

### Deployment Status
- ✅ Successfully deployed
- ✅ Firestore trigger active
- ✅ Automatically triggers on reaction creation

### How to Test:

#### **Test 1: From Flutter App**
1. **Boost a post first:**
   ```dart
   await postRepository.boostPost(
     postId: 'your-post-id',
     userId: 'your-user-id',
     boostPackage: BoostPackageModel.getDefaultPackages().first,
     targetingData: {},
   );
   ```

2. **Like/react to the boosted post:**
   ```dart
   await postRepository.likePost('your-post-id', 'your-user-id');
   ```

3. **Function automatically triggers!**
   - No manual call needed
   - Firestore trigger handles it

### Expected Result:
- Function logs: `"Tracked boost engagement for post {postId}"`
- Post document: `boostStats.engagement` increments by 1

### Check Logs:
```bash
firebase functions:log | findstr trackBoostEngagement
```

### Verification:
1. Check Firestore Console
2. Go to: `posts/{postId}`
3. Verify `boostStats.engagement` has increased

---

## Function 3: cleanupExpiredBoosts ✅

### Deployment Status
- ✅ Successfully deployed
- ✅ Scheduled in Cloud Scheduler
- ✅ Runs every 24 hours (UTC)

### How to Test:

#### **Test 1: Wait for Scheduled Run**
- Function runs automatically every 24 hours
- Check logs after 24 hours

#### **Test 2: Manual Trigger (Cloud Console)**
1. Go to: https://console.cloud.google.com/cloudscheduler?project=prototype-29c26
2. Find job: `cleanupExpiredBoosts-us-central1`
3. Click three dots → "Run now"
4. Wait 1-2 minutes
5. Check logs

#### **Test 3: Create Test Data**
1. Create a boosted post with past expiration:
   ```dart
   // Boost a post
   await postRepository.boostPost(...);
   
   // Manually set boostEndTime to past in Firestore Console
   // posts/{postId}/boostEndTime = Timestamp from yesterday
   ```

2. Trigger cleanup manually
3. Verify post has `isBoosted = false`

### Expected Result:
- Function logs: `"Cleaned up {count} expired boosts"`
- Expired posts: `isBoosted` set to `false`

### Check Logs:
```bash
firebase functions:log | findstr cleanupExpiredBoosts
```

---

## Complete Testing Workflow

### Step 1: Test trackBoostImpression
```dart
// In your Flutter app
final analytics = BoostAnalyticsService();
await analytics.trackBoostImpression('test-post-id');
```

### Step 2: Test trackBoostEngagement
```dart
// 1. Boost a post
await postRepository.boostPost(...);

// 2. Like the post
await postRepository.likePost(postId, userId);

// 3. Check Firestore - boostStats.engagement should increment
```

### Step 3: Test cleanupExpiredBoosts
- Go to Cloud Scheduler
- Manually trigger `cleanupExpiredBoosts`
- Check logs for execution

---

## View All Logs

```bash
# All boost function logs
firebase functions:log | findstr /i "boost"

# Specific function
firebase functions:log | findstr trackBoostImpression
firebase functions:log | findstr trackBoostEngagement
firebase functions:log | findstr cleanupExpiredBoosts
```

---

## Verification Checklist

- [x] `trackBoostImpression` deployed and visible in Firebase Console
- [x] `trackBoostEngagement` deployed and visible in Firebase Console
- [x] `cleanupExpiredBoosts` deployed and visible in Cloud Scheduler
- [x] `cloud_functions` package added to Flutter app
- [x] `BoostAnalyticsService` created and integrated
- [x] `PostCard` widget calls `trackBoostImpression` automatically
- [ ] Tested `trackBoostImpression` from app ✅
- [ ] Tested `trackBoostEngagement` by liking boosted post ✅
- [ ] Tested `cleanupExpiredBoosts` manually ✅

---

## Function URLs

- **trackBoostImpression**: `https://us-central1-prototype-29c26.cloudfunctions.net/trackBoostImpression`
- **trackBoostEngagement**: Firestore trigger (no URL)
- **cleanupExpiredBoosts**: Scheduled job (no direct URL)

---

## Quick Test Commands

```bash
# List all functions
firebase functions:list

# View logs
firebase functions:log

# Filter boost functions
firebase functions:log | findstr /i "boost"
```

---

**All functions are deployed and ready for testing!** 🚀

