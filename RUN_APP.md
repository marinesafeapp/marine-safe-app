# How to run Marine Safe app

## Option 1: Double‑click to run (easiest)
1. In **File Explorer**, go to: `c:\Users\77sho\marinesafe\marine\marine safe app`
2. **Double‑click** **Run App.bat**
3. A window opens and runs the app on your connected phone. When it says "Flutter run key commands", the app is running. (Press any key in that window to close it after you stop the app.)

## Option 2: Run from Cursor (F5)
F5 only works if the **Dart** and **Flutter** extensions are installed:
1. In Cursor: **Extensions** (Ctrl+Shift+X), search for **Flutter** and **Dart**, install both.
2. **File > Open Folder** and choose the **marine safe app** folder (the one that contains `pubspec.yaml`).
3. Press **F5** or use **Run > Start Debugging** and pick **"marine safe app"**.
If F5 still does nothing, use Option 1 (Run App.bat) instead.

## Option 3: Terminal in Cursor
1. **Open terminal:** `` Ctrl+` `` (backtick) or **Terminal > New Terminal**
2. If the shell is not in the project folder, run:
   ```powershell
   cd "c:\Users\77sho\marinesafe\marine\marine safe app"
   ```
3. Then run:
   ```powershell
   flutter run
   ```
   (Use **one line at a time** — in PowerShell don't use `&&` between commands.)

## Option 4: Run from Windows
1. Open **File Explorer** and go to: `c:\Users\77sho\marinesafe\marine\marine safe app`
2. In the address bar type **cmd** and press Enter (opens Command Prompt in that folder)
3. Type: **flutter run** and press Enter

## Smaller release APK (for sharing or Play Store)
- **Debug** APKs from `flutter run` are always large. For a **smaller** install:
  1. In the project folder, run: **flutter build apk --release**
  2. Output: `build\app\outputs\flutter-apk\app-release.apk` (shrunk, no debug symbols)
- Or build an **app bundle** (smallest download from Play): **flutter build appbundle --release**
  - Output: `build\app\outputs\bundle\release\app-release.aab`

## If "flutter" is not found
- Install Flutter: https://docs.flutter.dev/get-started/install/windows
- Or add Flutter to PATH (where you installed it, e.g. `C:\flutter\bin`)
