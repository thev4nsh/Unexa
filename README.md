# UNEXA — Your Campus. One Place.

A multi-tenant campus information platform built with Flutter + Firebase
(Firebase is the ONLY backend — no separate server needed).

## Roles & connections

| Role | Sees | Can do |
|---|---|---|
| **Owner** | Everything | Create colleges, override anything |
| **Admin** | Full dashboard | All college operations, ban at admin level |
| **Co-Admin** | Full dashboard | Same as admin except owner-level actions |
| **Moderator** | Verification only | Approve / reject / ban (moderator level) / unban own bans |
| **Student** | Student app | Timetable, announcements, calendar, documents, profile |

Every sensitive action is written to the append-only `auditLogs` collection, and
all authorization is enforced twice: in the UI (routing/visibility) and in
`firestore.rules` (server-side, cannot be bypassed).

## Build a release APK

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

The manifest already includes INTERNET/ACCESS_NETWORK_STATE permissions.

### Required before public release: real signing keys

`android/app/build.gradle.kts` currently signs release builds with the debug
key (fine for testing only). For Play Store distribution:

```bash
keytool -genkey -v -keystore %USERPROFILE%\unexa-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias unexa
```

Create `android/key.properties` (never commit it):

```properties
storePassword=<your password>
keyPassword=<your password>
keyAlias=unexa
storeFile=C:/Users/LOKI/unexa-release-key.jks
```

Then wire it in `android/app/build.gradle.kts` and **keep the .jks file safe** —
losing it means you can never update the app.

### SHA keys for Google Sign-In

Add both SHA-1 and SHA-256 of your signing key in
Firebase Console → Project settings → Your Android app:

```bash
keytool -list -v -keystore %USERPROFILE%\unexa-release-key.jks -alias unexa
```

Without the release SHA-1/SHA-256, Google Sign-In fails on installed APKs.

## Deploy Firebase backend (rules + indexes)

```bash
npm install -g firebase-tools
firebase login
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Rules enforce tenant isolation, ban hierarchy, and append-only audit logs
server-side.

## One-time Firebase Console setup

1. **Firestore Database** — create in production mode, then deploy rules above.
2. **Authentication → Sign-in method** — enable **Google**.
3. **Cloud Messaging** — works automatically; no server key needed since
   notifications are delivered via Firestore listeners + local scheduling.
4. **Storage** — rules already tenant-scoped (`colleges/{collegeId}/...`).

## First-run data setup (no code changes needed)

1. In Firestore, create `colleges/{collegeId}` with:
   `name`, `primaryColorHex`, `secondaryColorHex`, `allowedEmailDomains`
   (e.g. `["iitkalyani.ac.in"]`), `timezone` (e.g. `Asia/Kolkata`),
   `isActive: true`.
2. Sign in on the app with the owner/admin Google account.
3. Make that account staff by editing
   `colleges/{collegeId}/users/{uid}` → set `role: "admin"` and
   `accountStatus: "active"` (via Firebase Console — the app never allows
   clients to change roles).
4. Log in as Admin → **Academics** → add Departments → Batches → Sections.
5. Add Timetable entries, Calendar events, publish announcements and PDFs.
6. Students now select the college at login, sign in with their institute
   Google account, and wait for approval (moderators/admins approve them).

## Real-time behavior

- Approval/rejection/ban instantly reflect on the student's device
  (Firestore snapshot listener; no restart needed).
- Announcements appear in student apps within seconds of publishing.
- Daily 7:00 AM schedule briefing + 1-hour class/lab reminders are scheduled
  locally per device (survives offline; no backend cron needed).
- Any change made by admin/co-admin/moderator (timetable, calendar,
  announcements, branding, documents) reflects everywhere in real time.

## Development

```bash
flutter pub get
flutter analyze
flutter test
```
