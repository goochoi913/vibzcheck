# VibzCheck

![Team](https://img.shields.io/badge/Team-Goo%20Choi%20%26%20Eva%20Park-00bcd4) ![Course](https://img.shields.io/badge/Course-CSC%204360-1e88e5) ![Section](https://img.shields.io/badge/Section-Mobile%20App%20Dev%20Studio-43a047)

VibzCheck is a collaborative mobile music app built with Flutter and Firebase that lets friends create live listening rooms, add tracks from Spotify search, vote songs up or down in real time, and discuss the queue together with emoji-enhanced chat. Instead of one person controlling the aux, VibzCheck turns playlist curation into a shared social activity where everyone can contribute.

The app solves a common group-listening problem: static playlists and single-host control often make sessions feel one-sided. VibzCheck addresses this with democratic Firestore-powered queue reordering, mood-driven recommendation support via Cloud Functions, and session-wide notifications so collaborators stay synchronized even when they are navigating different screens.

## Team Members

| Name | Student ID | Role |
|---|---|---|
| Goo Choi | Submitted in course roster | Firebase foundation, playlist engine, vote transactions, recommendation + FCM backend, Phase 1/3/5/7/9 ownership |
| Eva Park | Submitted in course roster | Auth + profile UX, playlist UI, chat reactions, settings + docs polish, Phase 2/4/6/8 ownership |

## Features

- Real-time collaborative playlist sessions with host and collaborator roles
- Spotify track search through secure Firebase Cloud Functions
- Democratic voting using Firestore transactions with duplicate-vote protection
- Mood tagging on tracks and genre profiling for smarter recommendation seeds
- Real-time chat with long-press emoji reactions on message bubbles
- AI-driven recommendation retrieval from Spotify based on session mood tags
- Firebase Cloud Messaging (FCM) push notifications for queue updates
- User profiles with listening stats (sessions joined, votes cast, tracks added)
- Insights screen for mood profile, top-voted tracks, and recommendations

## Tech Stack

| Technology | Usage in VibzCheck |
|---|---|
| Flutter (Dart) | Cross-platform UI framework for all mobile screens and interaction logic |
| Provider | Lightweight app-wide state management for auth/session state and stream lifecycles |
| Firebase Authentication | Email/password account creation, login, and persisted user sessions |
| Cloud Firestore | Real-time storage for users, sessions, tracks, messages, votes, and profile stats |
| Firebase Cloud Functions (TypeScript) | Server-side Spotify API bridge, recommendations, and notification triggers |
| Firebase Cloud Messaging (FCM) | Push notifications for collaborative session events |
| Firebase Storage | Planned media/file storage support (avatars and future assets) |
| SharedPreferences | Local persistence for client-side settings like notification toggles |
| CachedNetworkImage | Efficient album-art and avatar image loading with cache support |
| url_launcher | Opens the project GitHub URL from in-app settings |

## Firebase Architecture

VibzCheck uses four Firebase services as its backend core.

- **Firebase Auth**: Handles sign-up, sign-in, sign-out, and persisted authentication sessions so users return directly to the app lobby after cold start.
- **Cloud Firestore**: Stores all collaboration data in real time. The `users` collection keeps profile/account metadata including `fcmToken`. The `sessions` collection stores each listening room (`hostUID`, name, active state, collaborators), with `tracks` and `messages` as per-session sub-collections. Tracks hold vote counts, mood tags, and source metadata. Messages hold sender identity, message text, and optional reaction.
- **Firebase Storage**: Reserved for media assets (profile pictures and future richer playlist/session assets) while current builds primarily use Spotify-hosted album art URLs.
- **Firebase Cloud Messaging**: Uses each user document's latest `fcmToken` to target push notifications when queue activity happens.

Firestore schema in practice mirrors `FIRESTORE_SCHEMA.md`: users are keyed by Auth UID, sessions are top-level room documents, tracks/messages are sub-collections under each session, and votes are transaction-protected per-track records.

## Installation Instructions

1. Clone the repository:
   `git clone https://github.com/goochoi913/vibzcheck.git`
2. Enter the project directory:
   `cd vibzcheck`
3. Install dependencies:
   `flutter pub get`
4. Add Firebase Android config:
   place `google-services.json` in `android/app/`
5. Run the app:
   `flutter run`

## Known Issues

- Spotify preview audio playback is not implemented in the current build.
- Room join by QR code is currently a UI placeholder and not yet wired to scanner/generation logic.

## Future Enhancements

- Full QR-based room invite + camera-based quick join flow
- In-app Spotify preview playback and richer track detail modal
- Collaborative playlist moderation tools (kick/remove permissions and room lock)
- Advanced analytics timeline in Insights (mood shifts and vote velocity over time)
- Optional Apple Music / YouTube Music provider expansion for broader compatibility
