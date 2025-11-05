# Logout Black Screen Issue Documentation

## Issue Summary

When the user logs out, a **black screen** appears instead of the `LoginScreen`. The issue also occurs when pressing the back button on tabs (like `FriendsListScreen`) that are embedded in `IndexedStack` (not pushed routes).

## Symptoms

1. **On Logout**: User sees a black screen instead of `LoginScreen`
2. **On Back Button from Tabs**: Black screen appears when pressing back on embedded screens
3. **Duration**: Screen stays black for a brief moment (disposal/transition gap) before `LoginScreen` builds

## Root Cause Analysis

### Primary Issue: LoginScreen Not Building During Widget Disposal Gap

The core problem is **NOT** missing background colors. The real issue is:

1. **Widget Disposal Gap**: When `MainScreenWrapper` is disposed (during logout or back button press), there's a brief moment where it's removed from the widget tree
2. **AuthWrapper Not Rebuilding Fast Enough**: `AuthWrapper`'s `BlocConsumer` doesn't rebuild immediately when `MainScreenWrapper` is disposed
3. **LoginScreen Delayed Build**: `LoginScreen` only builds after `AuthWrapper` rebuilds, but during the gap, nothing is rendered → **black screen**

### Flow During Logout:

```
1. User clicks logout
2. AuthBloc emits Unauthenticated state
3. MainScreenWrapper.dispose() is called
4. MainScreenWrapper removed from widget tree
5. [GAP] - AuthWrapper hasn't rebuilt yet
6. [BLACK SCREEN] - No widget in tree, default MaterialApp background is black
7. AuthWrapper finally rebuilds (BlocConsumer triggers)
8. LoginScreen builds
9. LoginScreen visible
```

### Flow During Back Button Press:

```
1. User presses back on FriendsListScreen (embedded in IndexedStack)
2. Navigator.pop() is called (but it's not a route, so behavior is undefined)
3. MainScreenWrapper tries to dispose
4. [GAP] - Widget tree is transitioning
5. [BLACK SCREEN] - No visible widget during transition
6. AuthWrapper eventually rebuilds and shows MainScreenWrapper again (since state is still Authenticated)
```

## Current Architecture

### AuthWrapper Structure

```dart
BlocConsumer<AuthBloc, AuthState>
  ├── listener: Logs state changes, schedules post-frame callbacks
  ├── buildWhen: Checks if state type changed
  └── builder:
      ├── AuthInitial → Loading Scaffold
      ├── Authenticated → StreamBuilder<UserModel>
      │   └── Returns MainScreenWrapper (wrapped in Scaffold)
      └── Unauthenticated → LoginScreen
```

### MainScreenWrapper Structure

```dart
MainScreenWrapper (StatefulWidget)
  ├── initState: Initializes services (SonarController, SyncManager, PresenceManager)
  ├── build: Returns const MainScreen()
  └── dispose: Cleans up services
```

### MainScreen Structure

```dart
MainScreen (StatefulWidget)
  └── IndexedStack
      ├── NearbyScreen (index 0)
      ├── MatchScreen (index 2)
      ├── FriendsListScreen (index 3) ← Has back button (WRONG for tab)
      └── MenuScreen (index 4)
```

## Attempted Fixes (Current State)

### ✅ Fix 1: Wrapped MainScreenWrapper in Scaffold

**Location**: `lib/main.dart` line 423-430

```dart
return Scaffold(
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  body: MainScreenWrapper(
    key: ValueKey(user.id),
    connectivityBloc: BlocProvider.of<ConnectivityBloc>(context),
  ),
);
```

**Purpose**: Ensures there's always a visible widget during disposal. If `MainScreenWrapper` is removed, the `Scaffold` with background color remains.

**Status**: ✅ Applied but may not fully solve the issue

### ✅ Fix 2: Hide Back Button on Tabs

**Location**: `lib/screens/friends_list_screen.dart` and `lib/screens/main_screen.dart`

**Changes**:
- Added `hideBackButton` parameter to `FriendsListScreen`
- Set `hideBackButton: true` when used as tab in `MainScreen`

**Status**: ✅ Applied - Prevents back button from appearing on tabs

### ⚠️ Fix 3: BlocConsumer with Enhanced buildWhen

**Location**: `lib/main.dart` line 317-326

```dart
buildWhen: (previous, current) {
  final shouldRebuild = previous.runtimeType != current.runtimeType ||
      (previous is Authenticated && current is Unauthenticated) ||
      (current is Unauthenticated && previous is! Unauthenticated);
  return shouldRebuild;
},
```

**Status**: ✅ Applied but may not trigger fast enough

### ⚠️ Fix 4: Post-Frame Callback in Listener

**Location**: `lib/main.dart` line 309-315

```dart
if (state is Unauthenticated || state is AuthError) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    debugPrint("AuthWrapper listener: Post-frame callback...");
  });
}
```

**Status**: ✅ Applied but callback doesn't force rebuild - only logs

## Known Issues

### 1. BlocConsumer Rebuild Timing

**Problem**: `BlocConsumer` checks `Equatable` equality before calling `buildWhen`. If multiple `Unauthenticated()` states are emitted in quick succession, `BlocConsumer` may skip rebuilds because Equatable considers them equal.

**Evidence**: Logs show `AuthBloc: Emitted Unauthenticated state for sign-out (was: Unauthenticated)` - state was already `Unauthenticated`, so emitting again doesn't trigger rebuild.

### 2. StreamBuilder Not Disposing Fast Enough

**Problem**: When `Authenticated` → `Unauthenticated` transition happens, the `StreamBuilder<UserModel>` inside `AuthWrapper` may not dispose immediately, delaying the rebuild.

**Location**: `lib/main.dart` line 345-438

```dart
return StreamBuilder<UserModel>(
  key: ValueKey('user_stream_authenticated_${state.user.uid}'),
  stream: locator<UserRepository>().getUserStream(state.user.uid),
  ...
);
```

### 3. Navigator.pop() on Embedded Widgets

**Problem**: `FriendsListScreen` is embedded in `IndexedStack`, not a pushed route. Calling `Navigator.pop()` has undefined behavior - it may try to pop `MainScreenWrapper` or do nothing.

**Impact**: Creates disposal gaps when back button is pressed on tabs.

## Potential Solutions (Not Yet Implemented)

### Solution 1: Force Immediate Rebuild on Unauthenticated State

**Approach**: Use `BlocListener` to call `setState()` when `Unauthenticated` is detected, even if `buildWhen` returns false.

```dart
listener: (context, state) {
  if (state is Unauthenticated && state != _lastKnownState) {
    // Force immediate rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {}); // Would need StatefulWidget
      }
    });
  }
},
```

**Challenge**: `AuthWrapper` is currently `StatelessWidget`. Would need to convert to `StatefulWidget`.

### Solution 2: Use Unique Keys for Unauthenticated States

**Approach**: Modify `Unauthenticated` state to include a unique identifier (timestamp or counter).

```dart
class Unauthenticated extends AuthState {
  final int rebuildKey;
  const Unauthenticated({this.rebuildKey = 0});
  
  @override
  List<Object?> get props => [rebuildKey];
}
```

**Challenge**: Would require modifying state structure and ensuring unique keys on each emission.

### Solution 3: Pre-build LoginScreen During Transition

**Approach**: Always build `LoginScreen` in the background and overlay it when `Unauthenticated` state is detected.

```dart
Stack(
  children: [
    // Main content
    if (state is Authenticated) MainScreenWrapper(),
    // Always-ready LoginScreen
    if (state is Unauthenticated || _isTransitioning)
      LoginScreen(),
  ],
)
```

**Challenge**: May cause performance issues and layout conflicts.

### Solution 4: Ensure MaterialApp Has Background Color

**Approach**: Add explicit background color to `MaterialApp` or root widget.

```dart
MaterialApp(
  theme: ...,
  builder: (context, child) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  },
)
```

**Status**: ✅ Partially implemented - Scaffolds have backgroundColor, but MaterialApp root may not.

### Solution 5: Use WillPopScope/PopScope to Prevent Back on Tabs

**Approach**: Wrap `FriendsListScreen` in `PopScope` to prevent navigation when used as tab.

```dart
PopScope(
  canPop: false, // Prevent popping when used as tab
  child: FriendsListScreen(...),
)
```

**Challenge**: Need to detect when used as tab vs standalone.

## Testing Scenarios

### Scenario 1: Normal Logout
1. User is authenticated and on `MainScreen`
2. User navigates to Menu tab
3. User clicks "Logout"
4. **Expected**: `LoginScreen` appears immediately
5. **Actual**: Black screen appears briefly, then `LoginScreen`

### Scenario 2: Back Button on Tab
1. User is on Friends tab (embedded in IndexedStack)
2. User presses back button
3. **Expected**: Nothing happens (tab can't be popped)
4. **Actual**: Black screen appears briefly, then returns to Friends tab

### Scenario 3: Logout During Profile Loading
1. User logs in
2. Profile is still loading (StreamBuilder in `waiting` state)
3. User logs out immediately
4. **Expected**: `LoginScreen` appears immediately
5. **Actual**: Black screen may appear if StreamBuilder doesn't dispose quickly

## Debug Logs to Monitor

When testing, watch for these log patterns:

```
AuthBloc: Handling SignOut event.
AuthBloc: SignOut started. Current state: Authenticated
AuthBloc: Emitted Unauthenticated state for sign-out (was: Authenticated)
AuthWrapper listener: State changed to Unauthenticated
AuthWrapper buildWhen: previous=Authenticated, current=Unauthenticated, shouldRebuild=true
AuthWrapper: Received AuthState -> Unauthenticated
AuthWrapper: State is Unauthenticated. Showing LoginScreen.
LoginScreen: initState completed. Screen is now visible.
```

**Problem Pattern** (when issue occurs):
- Missing `AuthWrapper buildWhen` or `AuthWrapper: Received AuthState` logs
- Gap between `AuthBloc: Emitted Unauthenticated` and `AuthWrapper: Received AuthState`

## Files Involved

1. **`lib/main.dart`**
   - `AuthWrapper` class (lines 295-449)
   - `MainScreenWrapper` class (lines 451-698)

2. **`lib/blocs/auth_bloc.dart`**
   - `SignOut` event handler
   - State emissions

3. **`lib/blocs/auth_state.dart`**
   - `Unauthenticated` state definition

4. **`lib/screens/main_screen.dart`**
   - `IndexedStack` with embedded screens
   - `BlocBuilder` for auth state

5. **`lib/screens/friends_list_screen.dart`**
   - Back button logic
   - `hideBackButton` parameter

## Related Issues

1. **Logout not working** - User data not loading (separate issue, documented elsewhere)
2. **White screen during navigation** - Similar root cause (missing backgrounds during transitions)
3. **Chat screen exiting on logout** - Null checks for `currentUser` (fixed)

## Next Steps

1. ✅ Document the issue (this file)
2. ⏳ Test Solution 1: Convert `AuthWrapper` to `StatefulWidget` with forced rebuild
3. ⏳ Test Solution 2: Add unique keys to `Unauthenticated` state
4. ⏳ Test Solution 4: Add MaterialApp background color
5. ⏳ Test Solution 5: Add `PopScope` to prevent back on tabs

## Priority

**Medium Priority** - Issue is visual/UX only, doesn't break functionality. Users can still logout successfully, just see a brief black screen.

---

**Last Updated**: [Current Date]
**Status**: Partially Fixed (back button removed, Scaffold wrapper added, but gap issue persists)
**Assigned To**: Future development cycle

