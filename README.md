# Marine Safe

Marine Safe is a Flutter app focused on marine safety workflows (ramps, trips, and overdue alerts), with Firebase integration and Android notification reliability hardening.

## Quick start (developers)

- **Install deps**:

```powershell
flutter pub get
```

- **Run on a connected Android device**:

```powershell
flutter run
```

## Sharing the app with evaluators (Android)

Use the provided build script to generate an installable APK for testers:

- `tools/build_eval_android.ps1`

See the full instructions in:

- `docs/ANDROID_EVALUATOR_BUILD.md`
- `docs/EVALUATOR_GUIDE.md`
- `docs/TEST_CHECKLIST.md`

## Sending to iPhone for testing

iOS builds must be done on a **Mac** with Xcode. To run on a real iPhone and send to testers (e.g. via TestFlight), see:

- **`docs/IOS_TESTING_GUIDE.md`** — one-time setup, Firebase iOS plist, signing, and TestFlight.

## Notes

- **Release signing for evaluation**: Android `release` builds are currently configured to use the debug signing key so the APK is installable for evaluation. For Play Store, we’ll switch to a real keystore.

