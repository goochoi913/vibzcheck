# Phase 3 Test Report (May 2, 2026)

## Automated checks completed locally

- `flutter analyze` -> passed with no issues.
- `flutter test` -> passed (`1` test, `0` failures).
- `npm --prefix functions run build` -> passed (TypeScript Cloud Functions compile).

## Firebase and deployment checks

- `firebase functions:config:set spotify.client_id=... spotify.client_secret=...` -> completed.
- `firebase deploy --only functions` -> blocked by plan requirement.
  - Error: project `vibzcheck-4bc2b` must be upgraded to Blaze to enable required APIs (`artifactregistry.googleapis.com`, `cloudbuild.googleapis.com`, `cloudfunctions.googleapis.com`).

## Manual app flow checklist

The following items are implemented in code and ready to verify on-device after Blaze upgrade:

- Auth persistence route: `main.dart` auth gate sends logged-in user to `MainNavigation`.
- Session lobby: create room/join room wired to Firestore via `SessionProvider` + `FirestoreService`.
- Spotify search and add track: modal sheet calls callable function and writes track to session sub-collection.
- Real-time session and track sync: provider subscriptions update UI with Firestore streams.

## Remaining manual verification in Firebase Console / emulator

- Confirm user document creation and `fcmToken` update after sign in/out.
- Confirm session document creation with host UID.
- Confirm track sub-document insertion under `sessions/{sessionId}/tracks` after selecting Spotify search result.
- Confirm callable functions appear in Firebase Console after successful deploy (requires Blaze upgrade).
