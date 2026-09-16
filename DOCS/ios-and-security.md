# UNEXA — iOS Build & Security Hardening Guide

## Part 1 — iOS Support

### 1.1 What's already in place (verified in repo)
- `ios/Runner.xcodeproj` exists with standard Runner target
- `Info.plist` has: UNEXA display name, Google Sign-In reversed client-ID URL scheme, `LSApplicationQueriesSchemes` for PDF viewers, portrait + landscape orientations, iPad orientation support
- All pubspec packages are iOS-compatible:
  - firebase_core/auth, cloud_firestore, firebase_storage — official plugins, iOS OK
  - google_sign_in 6.x — needs the URL scheme (already present)
  - cached_network_image, dio, path_provider, intl, timezone, shimmer, uuid, shared_preferences, url_launcher, file_picker, flutter_pdfview, flutter_local_notifications, go_router, flutter_riverpod — all support iOS
- No Android-only plugin usage found in lib/

### 1.2 What YOU must do (cannot be done from the code editor)

1. **Add GoogleService-Info.plist**
   - Firebase Console → Project settings → General → Your apps → add an **iOS app** (bundle ID must match Xcode, e.g. `com.example.unexa`)
   - Download `GoogleService-Info.plist` → open `ios/Runner.xcworkspace` in Xcode → drag the file into the Runner folder (check "Copy items if needed" + target Runner)
   - Without it, Firebase will crash on iOS launch

2. **Google Sign-In extra iOS steps**
   - Info.plist already has the reversed client-ID scheme
   - Firebase Console → Authentication → Sign-in method → Google: make sure it's enabled and your iOS bundle ID is registered as an OAuth client (the download in step 1 usually auto-creates it)

3. **Build & test on iOS** (needs a Mac with Xcode)
   - `cd ios && pod install --repo-update && cd ..`
   - `flutter build ios --release`
   - `flutter run -d <iphone-id>` for device testing
   - Signing: Xcode → Runner target → Signing & Capabilities → select your Apple ID team

4. **App Store submission (later, optional)**
   - App icon (AppIcon.appiconset), privacy policy URL, App Privacy answers (you collect name/email via Google Sign-In)
   - Screenshots + App Review notes (mention Google Sign-In for login)

## Part 2 — End-to-end protection ("uncrackable-ish")

Be realistic: no client app is literally uncrackable. What you get is layered defense so the
DATA stays safe even if the APK is reverse-engineered.

### 2.1 Already protecting you (server-side, the real wall)
- **Firestore security rules** — every role boundary (owner/admin/co_admin/moderator/cr/student),
  the ban hierarchy, disapprove permission, role-change matrix and audit-log immutability are all
  enforced SERVER-SIDE. A modified APK simply gets `permission-denied`.
- Ban/verification state lives in Firestore, never in the client.
- Audit logs are append-only — insiders cannot erase their trail.

### 2.2 Added in this change (client hardening)

#### Firebase App Check
- **Android:** Play Integrity attestation (debug provider registered for emulator/dev builds)
- **iOS:** App Attest (debug provider for simulator/dev builds)
- Start in **monitor mode**; flip products to **enforced** in the console after a clean week.
- Initialized at app startup in `lib/main.dart` via `SecurityService.initialize()`.

#### Screenshot blocking (Android)
- Verification, Activity Logs, Manage Moderators and Profile screens set `FLAG_SECURE`
  through a platform-adaptive `ScreenPrivacyGuard` — screenshots/recents-preview are blocked.
- iOS: Apple provides no public API to block screenshots/recording — that's an OS restriction,
  not an app gap. Blur-on-background is the accepted alternative (can be added later).

#### Release build hardening (Android)
- Build with:
  ```
  flutter build apk --release --obfuscate --split-debug-info=build/symbols
  ```
- ProGuard rules added in `android/app/proguard-rules.pro`
- Manifest flags:
  - `android:allowBackup="false"` — blocks adb backup extraction
  - `android:dataExtractionRules` (Android 12+) — no cloud/device-to-device restores
  - `android:usesCleartextTraffic="false"` — HTTPS only

### 2.3 What YOU must enable (Firebase Console — ~10 minutes)

1. **App Check**
   - App Check → Apps → register the **Android** app with **Play Integrity**
   - Register the **iOS** app with **App Attest**
   - Keep monitor mode ~1 week, then set Firestore + Storage to **Enforced**
2. **Firestore rules** — deploy the latest rules (the CR/Mod/Co-Admin + disapprove + admin-delete set I sent earlier)
3. **Auth hardening**
   - Authentication → Settings → enable **email enumeration protection**
4. **Storage rules** for the PDFs (replace the path prefix with your actual upload layout):
   ```
   rules_version = '2';
   service firebase.storage {
     match /b/{bucket}/o {
       match /{collegeId}/documents/{file} {
         allow read: if request.auth != null;
         allow write: if request.auth != null
           && firestore.get(/databases/(default)/documents/colleges/$(collegeId)/users/$(request.auth.uid)).data.role in ['admin', 'co_admin', 'owner'];
       }
     }
   }
   ```

### 2.4 Honest caveats (nothing client-side can fix these)
- Rooted/jailbroken devices can screenshot anything; FLAG_SECURE only stops normal users.
- The owner account is the root of trust — protect that Google account with 2FA.
- App Check blocks scripted abuse; it is not DRM. Together with the Firestore rules, your
  DATA is effectively uncrackable even if the binary is torn apart.
