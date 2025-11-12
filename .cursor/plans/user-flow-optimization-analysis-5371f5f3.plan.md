<!-- 5371f5f3-ff94-4068-99f5-2dcada5e8364 9be24dce-b654-4626-b668-337030850d36 -->
# User Flow Optimization Analysis & Refactoring Plan

## Overview

This plan analyzes and optimizes the complete user journey: **Sign Up/Login → Onboarding → App Services Initialization → Logout**, identifying memory leaks, inefficient Firestore calls, excessive internet usage, UX friction points, and design token inconsistencies.

## Analysis Summary

### 1. Memory Leak Issues

#### Login/Signup Screens

- **Issue**: `BlocConsumer` listeners may not properly dispose on navigation
- **Location**: `lib/screens/login_screen.dart`, `lib/screens/signup_screen.dart`
- **Impact**: Memory leaks when users navigate away during auth process

#### AuthWrapper Stream Management

- **Issue**: `getUserStream` in `AuthWrapper` may not cancel properly when auth state changes
- **Location**: `lib/main.dart:448-546`
- **Impact**: Firestore stream continues listening after logout, causing memory leaks and unnecessary reads

#### Onboarding Screen

- **Issue**: Multiple animation controllers, scroll controllers, and focus nodes may not dispose properly
- **Location**: `lib/screens/multi_step_onboarding_screen.dart`
- **Impact**: Memory leaks if user cancels onboarding mid-process

#### MainScreenWrapper Services

- **Issue**: `PresenceManager`, `SonarController`, `SyncManager` lifecycle management
- **Location**: `lib/main.dart:647-689`
- **Impact**: Services may continue running after logout if dispose is called during async operations

### 2. Firestore Call Inefficiencies

#### Duplicate User Stream Subscriptions

- **Issue**: `AuthWrapper` creates user stream, but other screens (e.g., `MainScreen`) may also subscribe
- **Location**: `lib/main.dart:448`, `lib/screens/main_screen.dart:76`
- **Impact**: Multiple Firestore listeners for same user document = wasted reads and costs

#### Unnecessary Retries in getUserStream

- **Issue**: `getUserStream` retries with 1-second delay even for new users
- **Location**: `lib/repositories/user_repository.dart:72-98`
- **Impact**: Unnecessary Firestore reads during signup flow

#### FCM Token Management

- **Issue**: Token saved on login AND potentially updated multiple times
- **Location**: `lib/services/fcm_token_service.dart:135-151`
- **Impact**: Redundant Firestore writes

#### Onboarding Profile Updates

- **Issue**: Image upload happens immediately when selected, then again on completion
- **Location**: `lib/screens/multi_step_onboarding_screen.dart:917-926`
- **Impact**: Potential duplicate uploads if user changes image

### 3. Internet/Data Usage Issues

#### Location Detection

- **Issue**: `_detectLocationAndCountry()` makes multiple API calls (Geolocator + Geocoding)
- **Location**: `lib/screens/multi_step_onboarding_screen.dart:441-572`
- **Impact**: High data usage, especially if user retries location detection

#### Image Upload Strategy

- **Issue**: Images uploaded immediately on selection, not batched with other profile data
- **Location**: `lib/screens/multi_step_onboarding_screen.dart:917-926`
- **Impact**: Multiple network requests instead of single batch update

#### Draft Saving Frequency

- **Issue**: Draft saved on every keystroke in onboarding
- **Location**: `lib/screens/multi_step_onboarding_screen.dart:355-365`
- **Impact**: Excessive SharedPreferences writes (minor, but unnecessary)

### 4. UX Friction Points

#### Hardcoded Design Values

- **Issue**: Login screen uses hardcoded spacing (`32.0`, `48.0`), colors (`Colors.orange`, `Colors.grey`)
- **Location**: `lib/screens/login_screen.dart:136, 151, 117, 268`
- **Impact**: Inconsistent UI, doesn't respect theme

#### Error Handling

- **Issue**: Generic error messages, no retry mechanisms for network failures
- **Location**: Multiple screens
- **Impact**: Poor user experience on network issues

#### Loading States

- **Issue**: Some async operations lack proper loading indicators
- **Location**: Onboarding location detection, image upload
- **Impact**: Users unsure if action is processing

#### Onboarding Back Navigation

- **Issue**: Confirmation dialog on back press may be too aggressive
- **Location**: `lib/screens/multi_step_onboarding_screen.dart:1312-1344`
- **Impact**: Friction for users who want to review previous steps

### 5. Dead/Legacy Code

#### WorkManager Code

- **Issue**: Commented out WorkManager initialization and callbacks
- **Location**: `lib/main.dart:143-178, 236-248`
- **Impact**: Code clutter, confusion

#### Old Onboarding References

- **Issue**: Comments reference old `OnboardingScreen` that no longer exists
- **Location**: `lib/main.dart:790-791`
- **Impact**: Confusion for developers

## Implementation Plan

### Phase 1: Memory Leak Fixes

1. **Fix AuthWrapper Stream Disposal**

- Add proper stream cancellation in `AuthWrapper` when auth state changes
- Use `StreamSubscription` with explicit cancellation
- Ensure `StreamBuilder` key changes force disposal

2. **Fix Onboarding Disposal**

- Ensure all controllers dispose in correct order
- Add `mounted` checks before `setState` in async callbacks
- Dispose image picker resources

3. **Fix Service Lifecycle**

- Ensure `PresenceManager.dispose()` completes before widget disposal
- Add timeout for service cleanup to prevent blocking logout
- Verify `SonarController` stops properly

### Phase 2: Firestore Optimization

1. **Consolidate User Stream Subscriptions**

- Create single user stream provider at app level
- Share stream across screens instead of multiple subscriptions
- Cache user data to reduce reads

2. **Optimize getUserStream Retry Logic**

- Remove automatic retry for new users (expected to not exist initially)
- Add retry only for existing users with transient errors
- Reduce retry delay from 1s to 500ms

3. **Batch Profile Updates**

- Combine image upload with other profile data in single transaction
- Use Firestore batch writes where possible
- Defer image upload until onboarding completion

4. **Optimize FCM Token Updates**

- Check if token changed before updating Firestore
- Debounce token updates to prevent rapid writes

### Phase 3: Internet/Data Optimization

1. **Optimize Location Detection**

- Cache location result to prevent re-detection
- Use lower accuracy for country detection (reduces data usage)
- Add manual country selection fallback

2. **Debounce Draft Saving**

- Save drafts with 500ms debounce instead of every keystroke
- Only save when user pauses typing

3. **Image Upload Optimization**

- Compress images before upload
- Show upload progress
- Allow cancellation of upload

### Phase 4: UX Improvements

1. **Apply Design Tokens to Login/Signup**

- Replace all hardcoded spacing with `DesignTokens.space*`
- Replace hardcoded colors with `SemanticColors` or `theme.colorScheme`
- Replace hardcoded border radius with `DesignTokens.radius*`
- Replace hardcoded font sizes with `theme.textTheme` or `DesignTokens.fontSize*`

2. **Improve Error Handling**

- Add specific error messages for common failures
- Add retry buttons for network errors
- Show user-friendly messages instead of raw exceptions

3. **Enhance Loading States**

- Add loading indicators for all async operations
- Show progress for image uploads
- Add skeleton loaders where appropriate

4. **Refine Onboarding UX**

- Make back navigation less aggressive (only on first step)
- Add skip option for optional fields
- Improve progress indicator visibility

### Phase 5: Code Cleanup

1. **Remove Dead Code**

- Delete commented WorkManager code
- Remove old onboarding screen references
- Clean up unused imports

2. **Add Documentation**

- Document service lifecycle management
- Add comments explaining stream disposal patterns
- Document Firestore query optimization strategies

## Files to Modify

### High Priority

- `lib/main.dart` - AuthWrapper stream management, service lifecycle
- `lib/screens/login_screen.dart` - Design tokens, memory leaks
- `lib/screens/signup_screen.dart` - Design tokens (mostly done, review)
- `lib/screens/multi_step_onboarding_screen.dart` - Memory leaks, Firestore optimization, UX
- `lib/repositories/user_repository.dart` - Stream retry optimization

### Medium Priority

- `lib/services/fcm_token_service.dart` - Token update optimization
- `lib/blocs/auth_bloc.dart` - Review for memory leaks
- `lib/services/presence_manager.dart` - Lifecycle verification

### Low Priority

- `lib/repositories/auth_repository.dart` - Code cleanup
- Remove commented WorkManager code

## Success Metrics

- **Memory**: No memory leaks detected in profiling
- **Firestore Reads**: Reduce by 30-40% through stream consolidation
- **Firestore Writes**: Reduce by 20% through batching and debouncing
- **Data Usage**: Reduce location detection calls by 50%
- **UX**: All screens use design tokens consistently
- **Code Quality**: Remove all dead code, improve documentation

### To-dos

- [ ] Fix AuthWrapper stream disposal - ensure getUserStream cancels properly when auth state changes
- [ ] Fix onboarding screen disposal - ensure all controllers, focus nodes, and image picker resources dispose correctly
- [ ] Fix service lifecycle management - ensure PresenceManager, SonarController dispose properly without blocking logout
- [ ] Consolidate user stream subscriptions - create single provider to share across screens
- [ ] Optimize getUserStream retry logic - remove automatic retry for new users, reduce delay
- [ ] Batch profile updates - combine image upload with other data in single transaction
- [ ] Optimize location detection - cache results, use lower accuracy, add manual fallback
- [ ] Debounce draft saving - save with 500ms delay instead of every keystroke
- [ ] Apply design tokens to login screen - replace all hardcoded spacing, colors, sizes
- [ ] Improve error handling - add specific messages, retry buttons, user-friendly text
- [ ] Enhance loading states - add indicators for all async operations, show upload progress
- [ ] Remove dead code - delete commented WorkManager code, old onboarding references