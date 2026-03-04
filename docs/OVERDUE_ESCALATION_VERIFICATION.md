# Overdue Escalation – On-Device Verification

This document lists steps to run and verify the cross-platform overdue escalation system **on real devices** (Android and iOS) after code changes.

## Prerequisites

- Physical Android device (API 24+) or iOS device
- App built in profile/release or debug with real signing
- Notifications and (on Android) exact alarms allowed for the app

## 1. Android

### 1.1 Permissions and manifest

- **POST_NOTIFICATIONS**: Requested in code via `requestNotificationsPermission()`; on first run user may need to allow in system settings.
- **SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM**: Requested in code via `requestExactAlarmsPermission()`; on some OEMs (e.g. Samsung) user may need to enable “Alarms & reminders” for Marine Safe.
- No extra manifest entries are required beyond what is already in `AndroidManifest.xml`.

### 1.2 Verify scheduling when trip starts

1. Open Marine Safe and sign in (or use anonymous).
2. Set a **Launch Ramp** and set **Return ETA** to a time **2–3 minutes from now**.
3. Start the trip (e.g. set people on board and confirm).
4. Confirm the persistent “trip active” notification appears (foreground service).
5. **Minimise or close the app** (swipe away from recents).
6. Wait until **ETA time**: you should get a notification (stage **DUE**): “Return ETA is now for …”.
7. Wait until **ETA + 5 minutes**: you should get a notification (stage **OVERDUE**): “OVERDUE return from …”.
8. Every **5 minutes** after that (up to 12 times): you should get repeated **ESCALATING** notifications until you open the app and acknowledge or end the trip.

### 1.3 Verify cancel on “I’m Safe”

1. With a trip active and overdue, open the app.
2. Tap “I’m Safe” (acknowledge).
3. Confirm a snackbar like “Overdue acknowledged”.
4. Close the app again and wait 10+ minutes: **no further overdue notifications** should fire.

### 1.4 Verify cancel on end trip

1. Start a trip with ETA in the future, then close the app.
2. Before ETA, open the app and **End trip**.
3. Close the app and wait past the original ETA and ETA+5: **no DUE or OVERDUE notifications** should fire.

### 1.5 Verify survival after app kill / reboot

1. Start a trip with ETA **10+ minutes** from now.
2. **Force-stop** the app (Settings → Apps → Marine Safe → Force stop) or **restart the device**.
3. Do **not** open the app again.
4. Wait until ETA: **DUE** notification should still fire.
5. Wait until ETA+5: **OVERDUE** notification should still fire.
6. (Optional) Wait for one or two escalation intervals: **ESCALATING** notifications should fire.

## 2. iOS

### 2.1 Permissions and plist

- Notification permission is requested via `DarwinInitializationSettings` (alert, sound, badge). User must allow when prompted.
- No additional plist keys are required for local notifications beyond what is already in `Info.plist`.
- All escalation notifications are **scheduled up front** when the trip is started; no Dart timers are used for scheduling.

### 2.2 Verify scheduling when trip starts

1. Open Marine Safe and set **Launch Ramp** and **Return ETA** (e.g. 2–3 minutes from now).
2. Start the trip.
3. **Send app to background** (home button or swipe up) or close the app.
4. Wait until **ETA**: **DUE** notification should appear.
5. Wait until **ETA + 5 minutes**: **OVERDUE** notification should appear.
6. Every **5 minutes** after that (up to 12 times): **ESCALATING** notifications should appear until you acknowledge or end the trip.

### 2.3 Verify cancel on “I’m Safe” and on end trip

- Same behaviour as Android: after **I’m Safe** or **End trip**, no further escalation notifications should fire, even if the app is closed.

### 2.4 Verify after app kill

1. Start a trip with ETA in the future.
2. Force-quit the app (swipe away from app switcher).
3. Wait until ETA and ETA+5: **DUE** and **OVERDUE** notifications should still fire.

## 3. Notification payload (last known location)

- If GPS tracking has stored at least one point for the current trip, escalation notifications (DUE / OVERDUE / ESCALATING) may include a line like:  
  **“Last known: &lt;lat&gt;, &lt;lng&gt; at &lt;time&gt;”**.
- To verify: start a trip, leave the app in foreground or background long enough for at least one location update, then trigger or wait for an escalation notification and check the body.

## 4. Summary checklist

| Step | Android | iOS |
|------|---------|-----|
| DUE at ETA when app closed | ✓ | ✓ |
| OVERDUE at ETA+5 when app closed | ✓ | ✓ |
| ESCALATING every 5 min (12×) when app closed | ✓ | ✓ |
| All cancelled on “I’m Safe” | ✓ | ✓ |
| All cancelled on End trip | ✓ | ✓ |
| Escalation survives app kill / reboot | ✓ | ✓ |
| Last known location in body (if available) | ✓ | ✓ |

## 5. Troubleshooting

- **No notifications on Android**: Check that “Notifications” are enabled for Marine Safe and, if prompted, “Alarms & reminders” (or equivalent) is allowed.
- **No notifications on iOS**: Check that Notifications are allowed for Marine Safe in Settings → Notifications.
- **Notifications late or inexact on Android**: Ensure exact alarm permission is granted; on some devices this is under “Alarms & reminders” or “Special app access”.
- **State lost after reboot**: Escalation state is persisted in SharedPreferences (trip active, ETA, acknowledged). Scheduling is re-applied from this state when the app is next opened; notifications themselves are scheduled with the OS and survive reboot as long as the app has not been uninstalled or data cleared.
