# WebRTC Fix Log

**Issue:** Race Condition in WebRTC signaling.

**Diagnosis:** The onConnected callback fires when the network connects, but before the video stream arrives. The UI switches to the video view too early, resulting in a black screen.

**Target Files:** 
- `lib/repositories/random_chat_repository.dart`
- `lib/screens/random_chat/random_chat_screen.dart`

**Status:** ALL APPLIED.

## Applied Changes
1.  **Repository:** Removed `onConnected?.call()` from `_peerConnection!.onConnectionState`. This prevents the UI from switching to "Connected" state before a track is received.
2.  **Screen:** Updated `build()` to check `_isConnected && _remoteRenderer.srcObject != null`. This ensures we never render the video view with a null stream.

## Verification Checklist
Please perform the following steps to verify the fix:
1.  **Restart App:** Fully close and restart to clear old states.
2.  **Join Random Chat:** Enter the queue.
3.  **Verify Local Camera:** Ensure your own face is visible in the background/preview.
4.  **Find Match:** Wait for a connection.
5.  **Verify Remote Video:** 
    - The "Searching" UI should disappear *only* when the remote video appears.
    - There should be NO black screen flickers.
    - If the connection is slow, you should see "Connected (Waiting for stream...)" toast/log, while still seeing the avatar/loader.
