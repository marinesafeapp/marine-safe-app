## Marine Safe – Evaluator Guide (Android)

### What you’re testing

Marine Safe is a marine safety app. The key behavior to evaluate is that **trip overdue alerts still fire even when the app is in the background / closed** (Android notification reliability varies by phone model).

### Install

1. Install the APK provided by the developer.
2. If Android blocks the install, allow installs from the source (Files/Chrome) when prompted.

### First launch permissions (recommended)

- **Notifications**: allow (needed for overdue alerts).
- **Location**: allow while using (maps and trip features).

### Important: Samsung / Android battery settings

Some Android phones (especially Samsung) may delay or block notifications to save battery.

If the app shows a “Notifications Reliability” dialog:

1. Tap **Open settings**
2. Set Battery usage to **Unrestricted** (or equivalent)
3. Disable Battery optimisation for Marine Safe (if present)

### Suggested test scenarios

- **Splash screen**: app shows Marine Safe logo, then proceeds to home.
- **Trip start → overdue**:
  - Start a trip with a short ETA (a few minutes).
  - Background the app (Home button).
  - Wait until it is overdue.
  - Confirm you receive an **OVERDUE** notification.
- **App closed**:
  - Start a short trip.
  - Swipe the app away (recent apps).
  - Wait until overdue time.
  - Confirm overdue notification still arrives.

### How to report feedback

Please include:

- Phone model + Android version (e.g. “Samsung S23 / Android 14”)
- What you did (steps)
- What you expected vs what happened
- Screenshot(s) if possible

