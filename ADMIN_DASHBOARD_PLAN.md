# Marine Safe Admin Dashboard Plan

## Goal
Separate all admin/moderator functionality from the public Marine Safe app and move it into a dedicated private admin app.

## Public Marine Safe App
On the next public app update:
- Remove the Admin / Moderator section completely.
- Remove admin login, dashboard screens and admin navigation from the public build.
- Keep all skipper-facing features unchanged.
- Keep Firebase communication required by the public app.
- Do not expose admin controls or admin-only data to normal users.

## New Private Admin App
Create a separate Flutter app named `marine_safe_admin` for authorised Marine Safe administrators only.

### Dashboard v1
- System status
- Registered users
- Active trips
- Overdue trips
- Last reported GPS/location
- App/user activity summary
- iOS / Android statistics where available

### Services
- Firebase status/data
- Twilio SMS status
- SMS usage/cost information where supported by APIs
- Cloud Functions status
- Notification/escalation status
- Website status

### Trip Management
For each active/overdue trip show:
- User/skipper
- People on board
- Launch ramp
- Departure time
- ETA
- Emergency contacts
- Last GPS location
- Last GPS update time
- Trip status

Admin actions:
- View trip details
- View last known location on map
- Acknowledge/administer incident
- End trip as admin when necessary

## Security Requirements
Do NOT store Firebase Admin credentials, Twilio auth tokens, Apple credentials, Google credentials or other privileged secrets directly in the mobile app.

Flow:
1. Admin signs into the private app.
2. Backend/Firebase verifies that account has an authorised admin role.
3. Privileged actions are executed through secure backend/Cloud Functions.
4. Firestore Security Rules must prevent normal public users from reading admin-only data or performing admin actions.

Use a role field/custom claims so admin permissions are enforced server-side, not just hidden in the UI.

## Build Order
1. Create `marine_safe_admin` Flutter project.
2. Connect it to the existing Marine Safe Firebase project (`marine-safe-app-494203`).
3. Add admin-only authentication and authorisation.
4. Build dashboard shell/navigation.
5. Connect registered-user data.
6. Connect active/overdue trips and GPS data.
7. Add trip detail and admin management actions.
8. Add Twilio/backend monitoring.
9. Add website/system status.
10. Test admin app on iPhone first.
11. Once admin app works, remove old Admin section from public Marine Safe codebase.
12. Test public app to ensure normal trip/safety functionality is unaffected.
13. Submit cleaned public app update to iOS and Android.

## Scope Guardrail
Keep v1 simple. The admin app should answer three questions quickly:

1. Is Marine Safe working?
2. Who is using it / who is currently on the water?
3. Is anybody overdue or in a state that needs attention?

Do not try to recreate the full Firebase, Twilio, Apple or Google consoles inside the first version.

## Cursor Instruction
Use this document as the implementation brief. Work through the Build Order sequentially. Before deleting the existing public-app admin code, first identify all admin/moderator routes, screens, services and Firestore permissions so shared public functionality is not accidentally removed.