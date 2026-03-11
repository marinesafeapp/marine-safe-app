# Google Play Store – Testing

Use this when preparing an update for **Internal testing** or **Closed testing** on Google Play Console.

**Ready for testing:** App label is "Marine Safe", release AAB is produced with `flutter build appbundle --release`, and signing uses `android/key.properties` when present (see below).

---

## 1. Version

- **versionName:** e.g. `1.0.1` (shown to users in store and in-app)
- **versionCode:** integer after `+` (must be **greater** than the previous release on Play)

Defined in `pubspec.yaml` as `version: 1.0.1+4`. For the next update, bump e.g. to `1.0.2+5` (versionCode must always increase).

---

## 2. Before you build (signed release for Play)

For **Play Store upload** you need a release keystore:

- [ ] Copy `android/key.properties.example` to `android/key.properties` (do not commit `key.properties`).
- [ ] Fill in `storeFile` (path to your `.jks` or `.keystore`), `storePassword`, `keyPassword`, `keyAlias`.
- [ ] Ensure the **release keystore** file exists at the path in `storeFile`.

Without `key.properties`, `flutter build appbundle --release` still runs and produces an AAB signed with the debug key (fine for local testing; **not** for Play Console upload).

- [ ] Optional: `flutter clean` then `flutter pub get`.

---

## 3. Build for Play Store

### Option A: Android App Bundle (recommended for Play)

Upload an **AAB** to Play Console; Play generates optimized APKs per device.

```bash
cd "/path/to/marine safe app"
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Upload this file in Play Console → your app → **Release** → **Testing** → **Internal testing** (or **Closed testing**) → **Create new release** → **Upload** (drag the AAB).

### Option B: Release APK (for evaluators or sideload testing)

Signed release APK for sharing outside Play (e.g. testers who aren’t in a testing track):

```powershell
pwsh -ExecutionPolicy Bypass -File "tools\build_eval_android.ps1"
```

This uses a timestamp as `versionCode` for the build; the copy is in `dist/marine-safe-eval-YYYYMMDD-HHmm.apk`.

For Play Store you should use the version from `pubspec.yaml` (Option A). Use Option B only for ad‑hoc APK sharing.

---

## 4. Upload to Play Console

1. Open [Google Play Console](https://play.google.com/console) → your app **Marine Safe**.
2. Go to **Testing** → **Internal testing** (or **Closed testing**).
3. **Create new release**:
   - Upload `app-release.aab` from `build/app/outputs/bundle/release/`.
   - **Release name** can be e.g. `1.0.1 (2)`.
   - Add **Release notes** (e.g. what’s new in 1.0.1).
4. **Review release** → **Start rollout to Internal testing** (or **Roll out** to Closed testing).

Internal testing is available within minutes to testers in the internal testing list.

---

## 5. Quick checklist

- [ ] Version in `pubspec.yaml`: versionCode (number after `+`) is **higher** than the last uploaded release.
- [ ] For Play upload: `android/key.properties` and release keystore are in place.
- [ ] `flutter build appbundle --release` completes successfully.
- [ ] `app-release.aab` uploaded to **Internal testing** (or Closed testing) in Play Console.
- [ ] Release notes added; rollout started so testers can install from the testing track.

---

## 6. First-time Play Console setup (if needed)

For a new app or first release, ensure in Play Console:

- **Store listing:** App name "Marine Safe", short/full description, screenshots, feature graphic, app icon.
- **Privacy policy:** Required (e.g. URL to your policy; needed for apps that collect data or use Firebase/location).
- **App content:** Declare data safety (Firebase Auth, Firestore, location, crashlytics), complete content rating questionnaire, and any other required forms.

---

## 7. If you need to bump version again

Edit `pubspec.yaml`:

- **Patch:** e.g. `1.0.1+4` → `1.0.2+5` (small fixes).
- **Minor:** e.g. `1.0.1+4` → `1.1.0+5` (new features).
- **Major:** e.g. `1.0.1+4` → `2.0.0+5` (big change).

`versionName` is the part before `+`, `versionCode` is the integer after `+`; **versionCode must always increase** for each Play Store upload.
