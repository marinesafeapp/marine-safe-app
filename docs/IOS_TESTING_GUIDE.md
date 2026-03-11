# iOS Testing Guide — Marine Safe

Get the Marine Safe Flutter app ready to run on iPhone and send to testers (e.g. via TestFlight).

---

## 1. You need a Mac (and Xcode)

- **Building for iOS must be done on macOS.** Windows cannot build or sign iOS apps.
- Install **Xcode** from the Mac App Store (latest stable).
- In Xcode: **Xcode → Settings → Locations** and set the **Command Line Tools** to your Xcode version.

---

## 2. One-time setup on the Mac

### 2.1 Flutter on the Mac

```bash
# If Flutter isn’t installed:
# https://docs.flutter.dev/get-started/install/macos

flutter doctor
```

Fix any issues reported (Xcode license, CocoaPods, etc.).

### 2.2 Apple Developer account

- **Apple Developer Program** ($99/year): required for **real devices** and **TestFlight**.
- Sign in at [developer.apple.com](https://developer.apple.com) with the same Apple ID you’ll use in Xcode.

### 2.3 Firebase — iOS app and GoogleService-Info.plist

The project already has **Firebase iOS config in code** (`lib/firebase_options.dart`). For full Firebase support (e.g. Crashlytics, Auth) on iOS, add the plist from Firebase:

1. Open [Firebase Console](https://console.firebase.google.com) → your project **marine-safe-app**.
2. **Project settings** (gear) → **Your apps**.
3. If there’s no iOS app, click **Add app** → **iOS**.
   - **Bundle ID:** `com.example.marineSafeNew` (must match `ios/Runner.xcodeproj`).
   - Register the app and download **GoogleService-Info.plist**.
4. If the iOS app already exists, open it and click **Download GoogleService-Info.plist**.
5. On the Mac, open the project in Xcode:
   ```bash
   cd /path/to/marine-safe-app
   open ios/Runner.xcworkspace
   ```
6. In Xcode: **Runner** (left sidebar) → right‑click **Runner** → **Add Files to "Runner"** → select **GoogleService-Info.plist** → leave “Copy items if needed” checked → **Add**.
7. Ensure **GoogleService-Info.plist** is in the **Runner** target and appears under **Runner** in the Project Navigator.

---

## 3. Open the project and set the team

1. On the Mac:
   ```bash
   cd /path/to/marine-safe-app
   open ios/Runner.xcworkspace
   ```
2. In Xcode, select the **Runner** project (blue icon) in the left sidebar.
3. Select the **Runner** target.
4. Open the **Signing & Capabilities** tab.
5. Check **Automatically manage signing**.
6. **Team:** choose your Apple Developer team (your Apple ID or your organization). If none appears, add your Apple ID in **Xcode → Settings → Accounts**.
7. Xcode will create a provisioning profile for the bundle ID `com.example.marineSafeNew`.

---

## 4. Run on a connected iPhone

1. Connect the iPhone with USB; on the device, tap **Trust** if asked.
2. In Xcode, choose your **iPhone** as the run destination (top toolbar).
3. First time on device: on the iPhone go to **Settings → General → VPN & Device Management** and trust your developer certificate.
4. Run from terminal:
   ```bash
   flutter run -d <your-iphone-id>
   ```
   Or in Xcode: **Product → Run** (⌘R).

If you see “Untrusted Developer”, use **Settings → General → VPN & Device Management** and trust your developer profile.

---

## 5. Send to testers via TestFlight

### 5.1 App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com).
2. **My Apps** → **+** → **New App**.
   - **Platforms:** iOS.
   - **Name:** Marine Safe (or your chosen name).
   - **Primary Language**, **Bundle ID** (`com.example.marineSafeNew`), **SKU** (e.g. `marine-safe-1`).
3. Create the app and open it.

### 5.2 Archive and upload

1. In Xcode, set the run destination to **Any iOS Device (arm64)** (not a simulator).
2. **Product → Archive**.
3. When the Organizer opens, select the new archive → **Distribute App**.
4. Choose **App Store Connect** → **Upload** → follow the steps (e.g. automatic signing, upload).
5. After processing (often 5–30 minutes), the build appears in App Store Connect under **TestFlight**.

### 5.3 Add testers

1. In App Store Connect, open your app → **TestFlight** tab.
2. **Internal Testing:** add people in your team (up to 100). They get the build quickly.
3. **External Testing:** create a group, add testers by email, submit the build for **Beta App Review** (first time). Once approved, testers get an email to install via TestFlight.

Testers need the **TestFlight** app on their iPhone and must accept the invite.

---

## 6. Optional: Ad Hoc / internal only (no TestFlight)

If you only need a few devices and don’t want TestFlight:

1. Register each tester’s device UDID in the [Apple Developer portal](https://developer.apple.com/account/resources/devices/list) (Devices).
2. In Xcode, create an **Ad Hoc** provisioning profile that includes those devices and your app’s bundle ID.
3. **Product → Archive** → **Distribute App** → **Ad Hoc** → export IPA.
4. Share the IPA and install via Apple Configurator, Xcode, or a distribution link (e.g. Diawi), respecting Apple’s distribution rules.

For most teams, **TestFlight is simpler** for “send to iPhone for testing”.

---

## 7. Checklist before sending to iPhone testers

- [ ] Mac with Xcode and Flutter installed; `flutter doctor` clean for iOS.
- [ ] **GoogleService-Info.plist** added to `ios/Runner` in Xcode (from Firebase Console).
- [ ] **Signing & Capabilities** in Xcode: Team set, automatic signing on.
- [ ] App runs on a real iPhone from Xcode or `flutter run`.
- [ ] For TestFlight: app created in App Store Connect, archive uploaded, TestFlight build processed, testers added (internal or external).

---

## 8. Bundle ID note

The app uses:

- **Android:** `com.example.marine_safe_new`
- **iOS:** `com.example.marineSafeNew`

They differ on purpose (Android uses underscores). Firebase is configured for both. If you later change the iOS bundle ID (e.g. to a reverse-DNS like `au.org.marinesafe.app`), update:

1. **Xcode** → Runner target → **General** → **Bundle Identifier**
2. **Firebase Console** → iOS app → re-download **GoogleService-Info.plist** for the new bundle ID (and add the new app if needed)
3. **lib/firebase_options.dart** — run `flutterfire configure` again so `iosBundleId` and options stay in sync

---

## Quick reference

| Goal                    | Where / How                                              |
|-------------------------|----------------------------------------------------------|
| Build & run on iPhone   | Mac + Xcode + `flutter run -d <iphone>` or Xcode Run    |
| Firebase on iOS        | Add **GoogleService-Info.plist** from Firebase Console  |
| Signing                 | Xcode → Runner → Signing & Capabilities → Team          |
| Send to testers         | TestFlight (archive in Xcode → upload → add testers)     |
