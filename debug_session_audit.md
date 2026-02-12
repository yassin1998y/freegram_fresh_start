# WebRTC Dual-Device Diagnostic Audit

This file is for manually collecting logs during the dual-emulator debug session. Copy paste relevant log snippets from your debug console into the sections below.

## Device A (Offerer - Emulator 5554)

### 1. Match Found Event
- Expected: `[WEBRTC_STATE_CHANGE] Match Found: {roomId: ...}`
- Actual Log:
[PASTE LOG HERE]

### 2. Offer Generation
- Expected: `[SDP_GENERATED] Created Offer`
- Actual Log:
[PASTE LOG HERE]

### 3. Connection State Transitions
- Expected: `[WEBRTC_STATE_CHANGE] ICE Connection State: checking -> connected`
- Actual Log:
[PASTE LOG HERE]

## Device B (Answerer - Emulator 5556)

### 1. Match Found Event
- Expected: `[WEBRTC_STATE_CHANGE] Match Found: {roomId: ...}` (Must match Device A's Room ID)
- Actual Log:
[PASTE LOG HERE]

### 2. Receiving Offer
- Expected: `[WEBRTC_STATE_CHANGE] Received Offer`
- Actual Log:
[PASTE LOG HERE]

### 3. Answer Generation
- Expected: `[SDP_GENERATED] Created Answer`
- Actual Log:
[PASTE LOG HERE]

### 4. Connection State Transitions
- Expected: `[WEBRTC_STATE_CHANGE] ICE Connection State: checking -> connected`
- Actual Log:
[PASTE LOG HERE]

## Analysis Checklist

- [ ] **Room ID Match:** Do both devices receive the *same* `roomId` in the `match_found` event?
- [ ] **Offer/Answer Flow:** Did Device A send an offer, and did Device B receive it? Did Device B send an answer, and did Device A receive it?
- [ ] **ICE Candidates:** Are both devices exchanging ICE candidates? Look for `[WEBRTC_STATE_CHANGE] Received Candidate`.
- [ ] **One-Way Failure:** Is one device stuck in `checking` while the other is `connected`?
- [ ] **Remote Description:** Did Device B successfully `setRemoteDescription` with the offer?

## Notes & Observations
[Add any other weird behavior or error logs here]
