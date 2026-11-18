# Firebase setup

Nothing in this folder contains secrets; the project ID is supplied locally in
`.firebaserc` or with `firebase use`.

## Current project

| Item | Value |
|---|---|
| Firebase project | `nijaora` |
| Firestore database | `(default)`, location `eur3` (Europe multi-region) |
| Android package | `com.nijaora.app` |
| Android app ID | `1:457961296179:android:518e0e27e67ee2f3afae46` |
| Web app ID | `1:457961296179:web:92ea8c16b62d3b8cafae46` |

Already done:

- `flutterfire configure` was used to generate the Firebase options files and
  Gradle wiring; the API keys have since been replaced with build-time defines
  and placeholders;
- debug SHA-1 and SHA-256 fingerprints were added to the Android app;
- Firestore was created and `firestore.rules` / `firestore.indexes.json` were
  deployed.

Still blocked on a **Blaze (pay-as-you-go) plan with a linked Cloud Billing
account**:

- **Phone Authentication** — since September 2024 Firebase requires billing for
  the SMS service. Without it, `identityPlatform:initializeAuth` returns
  `BILLING_NOT_ENABLED`, and the Authentication page shows "Get started" but
  cannot enable Phone.
- **Firebase Storage** — new default buckets require Blaze. Until then
  `firebase deploy --only storage` fails with "Firebase Storage has not been
  set up".

Upgrade in the console under **Usage and billing → Details & settings → Modify
plan → Blaze**, then:

1. **Authentication → Get started → Phone** → enable.
2. Add a test phone number (e.g. `+2348031234567` / `123456`) so development
   does not depend on SMS delivery.
3. **Storage → Get started**, then run
   `firebase deploy --only storage --project nijaora`.

Firestore itself works on Spark, so the database and rules are already live.

## 1. Create the project

```bash
firebase login
firebase projects:create nijaora-prod   # or use the console
cd firebase
firebase use --add                      # choose the project, alias "default"
```

Firebase API keys are intentionally **not stored in this repository**. Keep the
committed `lib/data/sources/firebase/firebase_options.dart` as-is: it reads the
keys from build-time variables. For a local Firebase-backed build, supply them
yourself:

```bash
flutter run \
  --dart-define=AUTH_BACKEND=firebase \
  --dart-define=FIREBASE_WEB_API_KEY=<web-api-key> \
  --dart-define=FIREBASE_ANDROID_API_KEY=<android-api-key>
```

For Android, copy `android/app/google-services.json` locally and replace the
placeholder Android API key. Never commit the filled-in file. You can use
`flutterfire configure` to look up your Firebase values, but do not overwrite
the checked-in `firebase_options.dart` with real keys.

The Gradle plugin entries are already present in `android/settings.gradle.kts`
and `android/app/build.gradle.kts`.

Verify the Gradle plugin was added. `android/settings.gradle.kts` should contain
`id("com.google.gms.google-services") version "..." apply false` and
`android/app/build.gradle.kts` should apply
`id("com.google.gms.google-services")`. If the CLI skipped it, add both by hand.


## 2. Enable products

In the Firebase console:

1. **Authentication → Sign-in method → Phone.** Add the Android app's SHA-1
   and SHA-256 fingerprints (`cd android && ./gradlew signingReport`).
2. **Firestore** in production mode.
3. **Storage** in production mode.
4. **Cloud Messaging** (optional until notifications are built).
5. **App Check** (Play Integrity for Android, reCAPTCHA Enterprise for web).

Web phone auth additionally needs a reCAPTCHA verifier and an authorised
domain. It is deliberately disabled in `FirebaseAuthRepository` until that
exists.

## 3. Deploy rules and indexes

From this folder:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Rules are the source of truth for client access; see the comments in
`firestore.rules`. Two rules matter most:

- ratings, review counts, light scores, verification and `isPublished` are
  server-owned — the client cannot change them;
- reviews are callable-only, so eligibility and anti-collusion checks cannot be
  bypassed.

## 4. Local emulators

```bash
firebase emulators:start
```

Auth `:9099`, Firestore `:8080`, Storage `:9199`, UI `:4000`.
`AUTH_BACKEND=firebase` still targets the live project; emulator wiring is a
later step (see `docs/architecture.md`).

The checked-in rules were started against a demo project (`demo-nijaora`) and
smoke-checked: public `categories` reads return 200, while anonymous
`adminAuditLogs` reads and `users/*` writes are denied (403). Re-run the
emulator after any rule change.

## 5. Seed reference data

Create these collections with the Admin SDK or the console:

- `categories/{id}`: `name`, `synonyms`, `description`
- `locations/{id}`: `type`, `name`, `parentId`, `aliases`, `adjacentIds`,
  `active`, `datasetVersion`

Client reads are public; writes are denied. The demo dataset in
`lib/data/demo/demo_locations.dart` and `demo_catalog.dart` is the intended
starting content.

## 6. Run the app against Firebase

```bash
flutter run --dart-define=AUTH_BACKEND=firebase
```

The demo backend (`AUTH_BACKEND=demo`, the default) keeps working for tests and
UI work. Demo OTP is `123456`.
