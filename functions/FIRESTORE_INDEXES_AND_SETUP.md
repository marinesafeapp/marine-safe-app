# Firestore indexes and Functions setup

## Firestore path for trips

Trips are stored at: **`trips/{tripId}`** where `tripId` is the signed-in user's UID.

## Indexes

The escalation function queries:

- `trips` where `active == true`

This is a single-field equality query, so **no composite index is required**. Firestore will use the default single-field index.

If you later add a compound query (e.g. `active == true` and `etaUtc <= ...`), create a composite index. For the current implementation we filter `etaUtc` in code after fetching active trips, so no extra index is needed.

## Twilio secrets (required for SMS)

Set these using Firebase Functions secrets:

```bash
cd functions
npx firebase functions:secrets:set TWILIO_ACCOUNT_SID
# Paste your Twilio Account SID when prompted

npx firebase functions:secrets:set TWILIO_AUTH_TOKEN
# Paste your Twilio Auth Token when prompted

npx firebase functions:secrets:set TWILIO_FROM_NUMBER
# Paste your Twilio phone number in E.164 (e.g. +61412345678)
```

Or with the Firebase CLI:

```bash
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_FROM_NUMBER
```

## Deploy

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

## Behaviour summary

- **ETA + 30 min**: SMS to primary emergency contact only (once per trip).
- **ETA + 40 min**: SMS to all emergency contacts (once per trip).
- Escalation stops immediately if the trip is **acknowledged** (`acknowledgedAtUtc` set) or **ended** (`endedAtUtc` set or `active == false`).
- Phone numbers must be stored in **E.164** (e.g. AU: `+614xxxxxxxx`).
