# Release signing — you don’t have the old keystore

Your app uses **Signing by Google Play**, so you can use a **new** upload key. Do this once, then use the new keystore for all future uploads.

---

## Part A: Create a new keystore and ask Google to use it

### 1. Open a terminal in the `android` folder

```powershell
cd c:\Users\77sho\Documents\marine_safe_app_fixed\android
```

### 2. Create a new keystore (choose a password and remember it)

```powershell
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

It will ask for:
- **Keystore password** — choose one and remember it (this is `storePassword`).
- **Key password** — you can use the same (this is `keyPassword`).
- **Name, org, etc.** — you can use “Marine Safe” or your name; it’s for display only.

The alias is **upload** (use this as `keyAlias` in `key.properties`).

### 3. Export the certificate (so Google can register the new key)

```powershell
keytool -exportcert -rfc -keystore upload-keystore.jks -alias upload -file upload_certificate.pem
```

Enter the keystore password when asked. This creates **upload_certificate.pem** in the `android` folder.

### 4. Request upload key reset in Play Console

1. Go to [Play Console](https://play.google.com/console) → your app.
2. Open **Release** → **Setup** → **App integrity**.
3. Find **Upload key certificate** and click **Request upload key reset** (or similar).
4. In the form:
   - **Package name:** `au.com.marinesafe.app`
   - **Upload the .pem file:** attach **upload_certificate.pem** (from the `android` folder).
   - **Reason:** e.g. “Lost previous upload key.”
5. Submit and wait. Google usually replies within 1–2 days. **Do not upload a new AAB until they confirm the reset.**

---

## Part B: After Google approves the new key

### 5. Create `key.properties`

In the **android** folder, create a file named exactly **key.properties** with (use the same password you set in step 2):

```
storeFile=../upload-keystore.jks
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
```

### 6. Build the bundle

From the project root:

```powershell
cd c:\Users\77sho\Documents\marine_safe_app_fixed
flutter build appbundle
```

### 7. Upload to Play

Upload **build\app\outputs\bundle\release\app-release.aab** in Play Console. It will be signed with your new upload key and Google will accept it.

---

**Summary:** Create new keystore → export .pem → request upload key reset in Play Console → after approval, add `key.properties` and run `flutter build appbundle` → upload the new AAB.
