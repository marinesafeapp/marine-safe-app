Firebase on iOS — add GoogleService-Info.plist
==============================================

1. Open Firebase Console → your project (marine-safe-app) → Project settings → Your apps.
2. Select the iOS app (bundle ID: com.example.marineSafeNew) or add it if missing.
3. Download "GoogleService-Info.plist".
4. In Xcode (open ios/Runner.xcworkspace): right-click Runner → Add Files to "Runner" → select GoogleService-Info.plist → Add.

Do NOT commit GoogleService-Info.plist if it contains secrets; add it to .gitignore if needed. The app also uses lib/firebase_options.dart for default config.

Full steps: see docs/IOS_TESTING_GUIDE.md
