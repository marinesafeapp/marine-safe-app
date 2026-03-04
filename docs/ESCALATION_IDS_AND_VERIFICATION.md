# Overdue escalation: notification IDs and verification

## 1. Notification IDs (exact list)

All IDs are managed by `TripEscalationService` and cancelled/rescheduled together.

| ID(s) | Stage | When | Title | Body |
|-------|--------|------|--------|------|
| **9101** | DUE | At ETA | Marine Safe — Due now | ETA reached. Tap to open Marine Safe. |
| **9102** | OVERDUE | ETA + 5 min | Marine Safe — Overdue | No check-in received. Tap to open Marine Safe. |
| **9200–9223** | ESCALATING | ETA + 10 min, then every 10 min (24 times) | Marine Safe — Overdue (Escalating) | Still no response. Tap to open Marine Safe. |

- **Cancel/reschedule**: `cancelForTrip()` cancels 9101, 9102, 9200..9223. `scheduleForTrip(eta, tripId)` cancels existing then schedules all of the above.
- **Persistence**: `trip_active`, `trip_eta_iso`, `trip_acked`, `trip_ended`, `trip_id`, `escalation_enabled` in SharedPreferences.

## 2. How to verify on a real phone

1. **Start trip with ETA 2 minutes ahead → confirm DUE fires**
   - Set ramp and ETA to 2 minutes from now. Start trip. Minimise or close the app.
   - At ETA time you should get one notification: **Marine Safe — Due now**, body “ETA reached. Tap to open Marine Safe.”

2. **Confirm OVERDUE fires 5 min after ETA**
   - Without opening the app, wait 5 minutes after ETA.
   - You should get **Marine Safe — Overdue**, body “No check-in received. Tap to open Marine Safe.”

3. **Confirm ESCALATING fires 10 min after ETA and repeats every 10 min**
   - Wait 10 minutes after ETA: first **Marine Safe — Overdue (Escalating)**.
   - Then every 10 minutes: same title/body again (up to 24 times, i.e. ~4 hours).

4. **Confirm “I’m Safe” cancels everything**
   - Start a trip with ETA in the future, close the app. Before or after DUE/OVERDUE, open the app and tap “I’m Safe” (acknowledge).
   - Close the app again. No further DUE/OVERDUE/ESCALATING notifications should fire.

5. **Confirm End Trip cancels everything**
   - Start a trip with ETA in the future, close the app. Open the app and tap End Trip.
   - Close the app again. No DUE/OVERDUE/ESCALATING notifications should fire at or after the original ETA.

## 3. Integration points (where code is called)

- **Start Trip** (trip active + ETA saved): `_syncSchedules()` → `TripEscalationService.instance.scheduleForTrip(eta, tripId)`.
- **“I’m Safe”**: `acknowledgeOverdue()` → `TripEscalationService.instance.acknowledgeTrip()`.
- **End Trip**: `endTrip()` → `TripEscalationService.instance.cancelForTrip()`.
- **ETA changed (extend/pick ETA)**: `extendEta()` / `pickEta()` → `_syncSchedules()` → `scheduleForTrip(eta, tripId)` (reschedules all).

## 4. Android / iOS config

- **Android**: `AndroidManifest.xml` must include `POST_NOTIFICATIONS` (Android 13+). Exact alarms: request in code via `requestExactAlarmsPermission()` (done in `notification_bootstrap.dart`).
- **iOS**: Notification permission is requested via `DarwinInitializationSettings` in plugin init; no extra plist key required for local notifications.
- **main.dart**: Calls `initNotifications()` early (after `WidgetsFlutterBinding.ensureInitialized()`, before Firebase) so timezone and notification permissions/channels are ready.
