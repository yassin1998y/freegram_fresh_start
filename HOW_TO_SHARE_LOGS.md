# How to Share Debug Console Output

This guide shows you multiple ways to capture and share debug logs with me for analysis.

## Method 1: VS Code Debug Console (Easiest) ✅

### Step 1: Start Debugging
1. Open VS Code
2. Press `Ctrl+Shift+D` (or click the debug icon)
3. Select **"Debug on Samsung SM A155F"** from dropdown
4. Press `F5` to start

### Step 2: Use the App
- Navigate to **Reels feed**
- Scroll through videos
- Navigate to **Stories**
- Try loading videos that previously had issues

### Step 3: Copy Console Output
1. Click on the **Debug Console** tab (at the bottom)
2. **Right-click** in the console → **Select All** (or press `Ctrl+A`)
3. **Copy** (press `Ctrl+C`)
4. **Paste here** in the chat

**Tip:** You can also right-click → "Copy All" for easier copying.

---

## Method 2: Using PowerShell Script (Recommended for Longer Sessions)

### Step 1: Run the Script
```powershell
.\scripts\capture_and_save_logs.ps1
```

### Step 2: Use the App
- Let the script run while you use the app
- Focus on testing reels and stories
- Scroll through videos

### Step 3: Stop and Share
1. Press `Ctrl+C` to stop capturing
2. The script will save a file like `debug_log_20241215_143022.txt`
3. Open the file
4. Copy all content (`Ctrl+A`, `Ctrl+C`)
5. Paste here

---

## Method 3: Manual Terminal Capture

### Step 1: Open Terminal
```powershell
# In PowerShell or Command Prompt
cd C:\Users\PC\StudioProjects\freegram_fresh_start
```

### Step 2: Capture Logs
```powershell
flutter logs --device-id R58X20FBRJX > debug_log.txt
```

### Step 3: Use the App
- Use the app normally in another window
- Test reels and stories

### Step 4: Stop and Share
1. Press `Ctrl+C` in terminal to stop
2. Open `debug_log.txt`
3. Copy all content and paste here

---

## Method 4: Filtered Logs (Only Important Stuff)

If you want to capture only relevant logs:

```powershell
flutter logs --device-id R58X20FBRJX | Select-String -Pattern "ReelsPlayerWidget|StoryViewerScreen|MediaPrefetchService|NetworkQualityService|NO_MEMORY|Codec|GetIt|LQIPImage" | Tee-Object -FilePath filtered_log.txt
```

Then share the `filtered_log.txt` file content.

---

## What to Include in Your Message

When sharing logs, please include:

1. **What you were testing:**
   - "Testing reels feed scrolling"
   - "Testing story video loading"
   - "Testing video playback"

2. **Any issues you noticed:**
   - "Videos still loading slowly"
   - "App crashed when opening reels"
   - "Got an error message"

3. **The log output:**
   - Full console output
   - Or paste the relevant sections

---

## Quick Tips

### ✅ Good Log Sharing:
- Include at least 50-100 lines of logs
- Show logs from when issues occurred
- Include timestamps
- Share error messages in full

### ❌ Avoid:
- Sharing only 1-2 lines
- Sharing logs from app startup only
- Not including error context

---

## Alternative: Screenshot Method

If copying text is difficult:

1. **Take a screenshot** of the Debug Console
2. **Attach the image** to your message
3. I can analyze from the screenshot

**To take screenshot:**
- Windows: `Win+Shift+S` (Snipping Tool)
- Then paste in chat or save and attach

---

## Expected Log Size

- **Small session (1-2 minutes):** ~500-1000 lines
- **Medium session (5 minutes):** ~2000-5000 lines
- **Large session (10+ minutes):** ~10000+ lines

**Don't worry about size** - I can analyze large logs. Just share what you have!

---

## Troubleshooting

### "Device not found"
- Make sure your Samsung device is connected via USB
- Enable USB debugging on your device
- Run: `flutter devices` to verify connection

### "No logs appearing"
- Make sure the app is running
- Try: `flutter logs --device-id R58X20FBRJX --verbose`

### "Script won't run"
- Make sure you're in the project root directory
- On Windows, you might need to: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

---

## Ready to Share?

Once you have the logs:
1. **Copy the console output**
2. **Paste it here** in our chat
3. **Tell me what you were testing**
4. I'll analyze and tell you if the fixes are working! 🚀

