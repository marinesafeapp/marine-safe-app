# Marine Safe

Marine Safe is a Flutter app focused on marine safety workflows (ramps, trips, and overdue alerts), with Firebase integration and Android notification reliability hardening.

## What Marine Safe does

- **Trip safety** — Set launch ramp and return ETA; start/end trip; GPS tracking during trip; trip state synced to cloud.
- **Overdue escalation** — If you don’t check in: Due at ETA → Overdue at ETA+5 min → “Tap to open SMS” to emergency contact at ETA+10 and ETA+20 → Marine Rescue suggestion at ETA+30 → Critical overdue at ETA+60. SMS includes vessel, ramp, ETA, last location, map link (user taps Send).
- **Profile & contacts** — Name, email, phone, postcode; Emergency contacts 1 & 2; used for escalation SMS and “Text emergency contact” when overdue.
- **Boat & safety** — Boat/vessel details; safety equipment checklist; compliance check before starting a trip.
- **Info** — Weather (Forecast tab), Tides, Can we fish here?, Fishing rules (quick actions on Trip tab).
- **Pro / crew** — Multiple vessels; Invite crew (join code + QR); Join boat to view someone else’s trip.
- **Moderator** — View active/ended trips and user details; End trip for a user.
- **Reliability** — Android foreground service so alerts fire when app is closed; battery optimisation prompt; exact alarms permission.

Full feature list: **`docs/FEATURES_OVERVIEW.md`** (one-pager for evaluators, App Store, or stakeholders).

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

