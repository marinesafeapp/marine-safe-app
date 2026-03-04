## Building an Android APK for evaluators

### Prereqs

- Flutter installed and on PATH
- Android SDK set up (Flutter doctor should be green for Android)
- A connected device is NOT required to build an APK

### Build (recommended)

Run the script:

```powershell
pwsh -ExecutionPolicy Bypass -File "tools\build_eval_android.ps1"
```

This produces:

- A **release** APK at `build/app/outputs/flutter-apk/app-release.apk`
- A copy in `dist/` with a timestamped filename (easy to share)

### Install (tester)

Send the APK to the tester (email, Drive, etc.) and have them open it on their phone to install.

If Android blocks it, they may need to allow installs from that source (Files/Chrome).

