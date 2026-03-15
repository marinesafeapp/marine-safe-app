# Marine Safe — Features overview (one-pager)

Use this for evaluators, App Store / Play Store descriptions, or stakeholder summaries.

---

## What Marine Safe does

Marine Safe is a marine safety app that helps skippers stay accountable on the water. You set a launch ramp and return time; if you don’t check in, the app escalates from reminders to prompting you to text your emergency contact, then suggests contacting Marine Rescue. It does **not** replace emergency services (000, VHF Ch 16) or marine communications.

---

### Onboarding & account

- First-time **registration**: name, phone, email, postcode, emergency contact (required).
- **Name setup** if name is missing after registration.
- **Splash** screen then routes to Register, Name setup, or main app.
- Anonymous **Firebase Auth** sign-in.
- **Reliability / disclaimer** screen: notifications may be delayed on some devices; app is not a substitute for 000 or marine comms.

---

### Main navigation (tabs)

- **Gear (Prepare)** — Shortcuts to Boat details, Safety equipment, Trip history (Pro), Marine Safe Pro, Join boat.
- **Forecast** — **Weather** (forecast by postcode/GPS) with categories (Weather, Rainfall, Wind, Sun, UV, Tides, Swell, Weekly); marine data (wave height, swell, sea surface temp); link to **Tides** screen via drawer.
- **Trip (Home)** — Core trip flow: select ramp, set ETA, start/end trip, manage trip, overdue alerts, quick actions (Tide times, Can we fish here?, Fishing rules).
- **Profile** — Name, email, phone, postcode; Emergency contact 1 (primary) & 2; save to device + cloud; Admin login (debug) → Moderator.
- **Sponsors** — Sponsor list/content.

---

### Trip management (Trip tab)

- **Select launch ramp** from Australian ramps list: filter by postcode (“Near your postcode within 200 km”), **favourites** chips, or “Near me” (GPS); mark favourites.
- **Set return ETA** (time picker).
- **Start trip** — Saves trip active, ramp, ETA, vessel name; starts Android foreground service so alerts fire when app is closed. **Pro**: choose vessel when multiple vessels exist.
- **Manage trip** (bottom sheet) — Extend ETA (+30 min / +1 hr), people on board, Acknowledge overdue, Text emergency contact, End trip; **Invite crew** (join code + QR) for Pro.
- **End trip** — Confirmation; clears trip state, stops service, cancels all escalation, syncs “ended” to cloud.
- **Trip status** — “Trip in progress” / “Ready to go”; overdue state and in-app overdue dialog; **ACKNOWLEDGE OVERDUE** when overdue.
- **GPS tracking** during trip (points stored locally in SQLite, synced to Firestore when online); last known location used in escalation SMS.

---

### Overdue escalation (if skipper doesn’t acknowledge)

| When        | Action |
|------------|--------|
| **ETA (0–5 min)** | Due notification to skipper. |
| **ETA + 5 min**   | Overdue notification to skipper. |
| **ETA + 10 min**  | Notification: “Send overdue alert to [primary contact] — tap to open SMS.” Tapping opens SMS app with prefilled message (vessel, ramp, ETA, last location, map link). |
| **ETA + 20 min**  | Notification: “Send overdue alert to all contacts — tap to open SMS.” Same SMS flow. |
| **ETA + 30 min**  | Notification: consider contacting Marine Rescue / 000. |
| **ETA + 60 min**  | Critical overdue notification. |

- **SMS message** includes vessel name, launch ramp, planned return time, last known GPS, map link. User taps Send in SMS app (no automatic sending from the app).
- **Overdue dialog** in app: “TEXT EMERGENCY CONTACT” and “ACKNOWLEDGE”; Manage trip sheet has “Text emergency contact” when overdue.
- **Notification tap** (ETA+10 / ETA+20) opens app then SMS app with the escalation message (handled when opening Trip tab or on cold start).

---

### Profile & emergency contacts

- **Profile**: Display name, email, phone, postcode; Emergency contact 1 (primary) & 2 (name, phone, relation); saved to device and Firestore.
- Emergency contacts are edited in Profile (expandable sections); primary contact used for escalation SMS and notification text (“Send to [name]”).

---

### Boat & safety

- **Boat details** — Default boat: name, boat rego, boat rego expiry, trailer rego, trailer rego expiry; **boat photo(s)** (one free; Pro: more, up to 10). **Pro**: multiple **vessels** (boat or jet ski), add/edit per vessel (name, type, rego, trailer, expiry); select vessel for the trip from Trip tab.
- **Safety equipment** — Checklist per vessel (or default): PFDs (inspection due), EPIRB expiry, flares expiry, extinguisher (present + expiry). Stored in TripPrefs; **compliance** check before starting a trip (rego, gear) and optional disclaimer.
- **Compliance** — Alerts if boat rego or safety gear is missing or incomplete when starting a trip.

---

### Info & quick actions (Trip tab)

- **Tide times** — Tide times (TidesScreen).
- **Can we fish here?** — Fishing eligibility.
- **Fishing rules** — Fishing rules content.
- Quick action bar on Trip: Tide times, Fish here?, Rules.

---

### Pro & crew

- **Pro** — Multiple vessels; boat photos (up to 10); Trip history; “Invite crew” (join code + QR) so others can view the trip.
- **Join boat** — Enter join code to view someone else’s trip (read-only summary).

---

### Admin & moderator

- **Admin login** (from Profile, debug only) — Unlocks **Moderator** access.
- **Moderator** — List of active/ended trips (filter: all / overdue / active); search; open **trip details**: Live summary (ramp, ETA, people on board, status, overdue ack), User profile (name, phone, email), Emergency contact, Safety quick view (PFD count, flares/EPIRB/extinguisher dates), Trip details, **last known location** (map when overdue); **End trip** for a user (writes to Firestore).

---

### Settings & reliability

- **Reliability / notification** — Shown once after registration or first trip; option to open notification/battery settings.
- **Battery optimisation** — Android prompt (e.g. Samsung) so notifications aren’t blocked.
- **Exact alarms** — Android permission for on-time escalation notifications.
- **Trip history** (Gear tab, Pro only) — List of past trips (ramp, start, stop, ETA) from local/cloud storage.

---

### Technical / backend

- **Firebase**: Auth (anonymous), Firestore (users profile, trips, trip codes, GPS points, moderator data), Crashlytics.
- **Local notifications** — Scheduled at ETA, ETA+5, +10, +20, +30, +60; payloads for “open SMS” on tap.
- **Foreground service** (Android) — Keeps trip active so overdue checks and notifications run when app is killed.
- **Trip cloud** — Upsert trip (ramp, ETA, active, overdue ack); mark ended; join codes for crew.
- **GPS tracking** — SQLite locally; sync points to Firestore when online; last location in escalation SMS.
- **Escalation** — All scheduled notifications cancelled on “I’m Safe” (acknowledge) or End trip; rescheduled when ETA is extended.

---

*Last updated to match the current codebase and escalation plan.*
