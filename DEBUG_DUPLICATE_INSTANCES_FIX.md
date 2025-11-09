# Debug Duplicate Instances Fix

**Issue:** When starting debug, two instances appear in the call stack.

---

## 🔍 **Common Causes:**

### 1. **Hot Restart vs Hot Reload**
- Flutter hot reload keeps the old instance in memory
- Hot restart creates a new instance
- Both might appear in call stack during transition

### 2. **Multiple Debug Sessions**
- VS Code might have multiple debug sessions running
- Check Debug panel for multiple active sessions

### 3. **Flutter Engine + App Process**
- Flutter debugger attaches to both:
  - Flutter Engine process
  - Dart app process
- This is normal but can appear as "duplicate"

### 4. **App Initialization Running Twice**
- `main()` function called twice
- WidgetsFlutterBinding initialized multiple times

---

## ✅ **Solutions:**

### Solution 1: Stop All Debug Sessions
1. Press `Shift + F5` (Stop All)
2. Wait for all processes to stop
3. Start fresh debug session

### Solution 2: Clean and Restart
```bash
flutter clean
flutter pub get
# Then start debug again
```

### Solution 3: Check for Multiple Debug Configurations
- Make sure only ONE debug configuration is running
- Close duplicate debug sessions in VS Code

### Solution 4: Disable Hot Reload on Debug Start
Add to `.vscode/launch.json`:
```json
{
  "name": "Debug on Samsung SM A155F",
  "request": "launch",
  "type": "dart",
  "deviceId": "R58X20FBRJX",
  "program": "${workspaceFolder}/lib/main.dart",
  "args": ["--verbose"],
  "hotReloadOnSave": false,  // Prevent hot reload during debug
  "hotRestartOnSave": false   // Prevent hot restart during debug
}
```

### Solution 5: Verify Single `main()` Call
- Ensure `main()` is only called once
- Check for duplicate `runApp()` calls

---

## 🔧 **Quick Fix:**

1. **Stop all debug sessions** (Shift + F5)
2. **Close VS Code completely**
3. **Restart VS Code**
4. **Start debug session fresh**

---

## 📝 **Note:**

If you see two entries in call stack like:
- `main()` at `main.dart:181`
- `_startMicrotaskLoop()` at `schedule_microtask.dart:49`

This is **NORMAL** - one is the app entry point, the other is the async event loop. They're not duplicates, just different stack frames.

---

## ✅ **Checklist:**

- [ ] Stop all debug sessions
- [ ] Check for multiple debug configurations
- [ ] Verify single `main()` function
- [ ] Clean Flutter build cache
- [ ] Restart VS Code
- [ ] Start fresh debug session

