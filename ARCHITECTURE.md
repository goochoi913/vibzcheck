# VibzCheck Architecture Decisions

## Overall Pattern

VibzCheck follows a layered architecture: **Presentation (screens/widgets)**, **Provider state layer**, **Service layer**, and **Firebase backend**. The UI reads state through providers and emits user intents; providers coordinate stream lifecycles and async actions; services isolate backend calls; Firebase supplies persistence and real-time sync.

We intentionally did not choose BLoC for this project. Most state in VibzCheck is session-scoped or screen-local, and Provider gives enough structure with far less boilerplate. For a semester project, this kept implementation velocity high while still preserving clean separation of responsibilities.

## Folder Structure

- `lib/screens/`: route-level UI surfaces only
- `lib/widgets/`: reusable UI components
- `lib/providers/`: app-wide/session-wide state objects and listeners
- `lib/firebase/`: service classes that own Firebase calls
- `lib/models/`: typed data contracts (`fromMap`, `toMap`, `copyWith`)
- `lib/utils/`: theme/constants/transitions

Screens do **not** call Firebase directly (with narrow, intentional exceptions). This rule reduces duplicate query logic, keeps security-sensitive operations centralized, and makes behavior easier to test and explain in demo Q&A.

## FirestoreService Singleton

`FirestoreService` is a singleton so the app shares one service instance everywhere. This prevents accidental duplication of listener setup code and keeps query/transaction behavior consistent across screens.

A singleton here also improves maintainability: when Firestore query strategy changes (pagination, retries, transaction shape), we update one class rather than many UI files.

## Provider for Auth and Session

`AuthProvider` is app-wide because auth state must survive tab switches, route transitions, and cold-start restore logic. It listens to Firebase auth changes once and exposes canonical signed-in user state to all screens.

`SessionProvider` is also app-wide during runtime because session metadata, tracks, votes, and banner cues are shared across Home/Playlist/Chat/Insights tabs. Unlike auth state, it can be safely reset on leave session, which clears subscriptions and in-memory session data.

## Cloud Functions Architecture

Spotify credentials are stored in Cloud Functions secrets/environment config and never embedded in the Flutter client binary. This avoids leaking API credentials through app reverse engineering.

The client calls callable functions (`searchSpotifyTracks`, `getRecommendations`, etc.), while OAuth token exchange and Spotify requests run server-side. This design protects secrets and keeps API policy changes isolated from client release cycles.

## Atomic Transactions for Voting

A naive `set()`-based vote update can drop increments during concurrent writes when multiple collaborators vote at nearly the same time. VibzCheck uses Firestore `runTransaction()` to read current vote state, enforce duplicate-vote guards, and commit consistent increments/decrements atomically.

This guarantees queue order correctness under concurrent collaboration and prevents race-condition regressions.

## Recommendation Engine Design

Recommendations are driven by mood tags attached to tracks. The function aggregates tag frequency, maps high-signal tags to Spotify seed genres, and requests recommendations from Spotify using those seeds.

Cloud Functions was chosen over on-device recommendation logic because it centralizes API access, protects credentials, and allows easy tuning of mood-to-genre mapping without forcing client updates.

## Real-Time Data Strategy

VibzCheck uses **stream listeners** for truly live collaborative surfaces (playlist tracks, session state, chat messages), where users need updates as they happen.

It uses **one-shot Futures** for snapshot-style data (profile stats, host name lookups, settings actions) where continuous real-time updates are unnecessary. This hybrid strategy balances responsiveness, read cost, and code clarity.
