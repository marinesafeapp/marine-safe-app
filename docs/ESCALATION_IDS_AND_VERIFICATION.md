# Overdue escalation: notification IDs and verification

## 1. Marine Safe Escalation Plan (timeline)

| Stage | When | Action |
|-------|------|--------|
| 1 | ETA (0–5 min grace) | App sends **Due** notification to skipper |
| 2 | ETA + 5 min | App sends **Overdue** alert to skipper |
| 3 | ETA + 10 min | **SMS to primary contact** — notification: "Send overdue alert to [name] — tap to open SMS" |
| 4 | ETA + 20 min | **SMS to all contacts** — notification: "Send overdue alert to all contacts — tap to open SMS" |
| 5 | ETA + 30 min | App recommends **contact Marine Rescue** |
| 6 | ETA + 60 min | **Critical overdue** notification |

## 2. Notification IDs (exact list)

All IDs are managed by `TripEscalationService` and cancelled/rescheduled together.

| ID | Stage | When | Title | Body / payload |
|----|--------|------|--------|----------------|
| **9101** | DUE | At ETA | Marine Safe — Due now | ETA reached. Tap to open Marine Safe. |
| **9102** | OVERDUE | ETA + 5 min | Marine Safe — Overdue | No check-in received. Tap to open Marine Safe. |
| **9103** | SMS primary | ETA + 10 min | Marine Safe — Contact your emergency contact | Send overdue alert to [name] — tap to open SMS. (payload: `escalation_sms_primary`) |
| **9104** | SMS all | ETA + 20 min | Marine Safe — Alert all contacts | Send overdue alert to all contacts — tap to open SMS. (payload: `escalation_sms_all`) |
| **9105** | Marine Rescue | ETA + 30 min | Marine Safe — Consider Marine Rescue | Trip is 30 min overdue. Consider contacting Marine Rescue or 000 if you have concerns. |
| **9106** | Critical | ETA + 60 min | Marine Safe — CRITICAL OVERDUE | Trip is 1 hour overdue. Open Marine Safe to acknowledge or contact emergency services. |

- **Cancel/reschedule**: `cancelForTrip()` cancels 9101–9106. `scheduleForTrip(eta, tripId, rampName, vesselName, primaryContactName)` cancels existing then schedules all of the above.
- **Persistence**: `trip_active`, `trip_eta_iso`, `trip_acked`, `trip_ended`, `trip_id`, `escalation_enabled` in SharedPreferences.
- **Notification tap**: When user taps 9103 or 9104, payload is stored; HomeScreen opens SMS app with prefilled escalation message (vessel, ramp, ETA, last known location, map link).

## 3. SMS message format (escalation)

Example body when opening SMS from ETA+10 / ETA+20 notification (or manual "Text emergency contact"):

```
Marine Safe Alert
Chrisso's vessel (My Boat) is overdue.

Last known location: -21.1156, 149.1852
https://maps.google.com/?q=-21.1156,149.1852
Launch ramp: Mackay Harbour
Planned return: 5:30 PM

Try contacting the skipper.
```

## 4. How to verify on a real phone

1. **Start trip with ETA 2 minutes ahead → confirm DUE fires**
   - Set ramp and ETA to 2 minutes from now. Start trip. Minimise or close the app.
   - At ETA time you should get one notification: **Marine Safe — Due now**.

2. **Confirm OVERDUE fires 5 min after ETA**
   - Without opening the app, wait 5 minutes after ETA.
   - You should get **Marine Safe — Overdue**.

3. **Confirm ETA+10: "Contact your emergency contact"**
   - Wait 10 minutes after ETA. You should get **Marine Safe — Contact your emergency contact**, body "Send overdue alert to [name] — tap to open SMS."
   - Tap the notification → app opens and SMS app opens with prefilled message (vessel, ramp, planned return, last location, map link).

4. **Confirm ETA+20, +30, +60**
   - ETA+20: "Alert all contacts — tap to open SMS."
   - ETA+30: "Consider Marine Rescue."
   - ETA+60: "CRITICAL OVERDUE."

5. **Confirm "I'm Safe" or End Trip cancels everything**
   - Start a trip with ETA in the future, close the app. Open the app and tap "I'm Safe" or End Trip.
   - No further escalation notifications should fire.

## 5. Integration points (where code is called)

- **Start Trip**: `_syncSchedules()` → `TripEscalationService.instance.scheduleForTrip(eta, tripId, rampName, vesselName, primaryContactName)`. Vessel name persisted in TripPrefs when trip starts.
- **"I'm Safe"**: `acknowledgeOverdue()` → `TripEscalationService.instance.acknowledgeTrip()`.
- **End Trip**: `endTrip()` → `TripEscalationService.instance.cancelForTrip()`.
- **ETA changed (extend/pick ETA)**: `extendEta()` / `pickEta()` → `_syncSchedules()` → `scheduleForTrip(...)` (reschedules all).
- **Notification tap (9103/9104)**: `notification_bootstrap` stores payload in prefs; HomeScreen reads it and calls `EmergencySmsService.openEscalationSmsToPrimaryContact(context)`.

## 6. Android / iOS config

- **Android**: `AndroidManifest.xml` must include `POST_NOTIFICATIONS` (Android 13+). Exact alarms: request in code via `requestExactAlarmsPermission()` (done in `notification_bootstrap.dart`).
- **iOS**: Notification permission is requested via `DarwinInitializationSettings` in plugin init; no extra plist key required for local notifications.
- **main.dart**: Calls `initNotifications()` early (after `WidgetsFlutterBinding.ensureInitialized()`, before Firebase) so timezone and notification permissions/channels are ready.
