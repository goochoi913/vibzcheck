# VibzCheck Firestore Schema

This document defines the Phase 1 Firestore structure for VibzCheck.

## Top-Level Collections

### `users` collection

Each document ID is the Firebase Auth UID.

| Field | Type | Required | Notes |
|---|---|---|---|
| displayName | string | yes | User display name |
| email | string | yes | Auth email |
| photoURL | string (nullable) | no | Profile image URL |
| favoriteGenres | array<string> | yes | User genre preferences |
| createdAt | timestamp | yes | Account creation timestamp |
| fcmToken | string | yes | Updated on each login |

### `sessions` collection

Each document represents a listening room.

| Field | Type | Required | Notes |
|---|---|---|---|
| hostUID | string | yes | UID of room host |
| sessionName | string | yes | Display room name |
| isActive | boolean | yes | Whether room is active |
| createdAt | timestamp | yes | Session creation time |
| collaborators | array<string> | yes | UIDs that can collaborate |

#### `sessions/{sessionId}/tracks` sub-collection

| Field | Type | Required | Notes |
|---|---|---|---|
| spotifyTrackId | string | yes | Spotify track ID |
| trackName | string | yes | Song title |
| artistName | string | yes | Artist display name |
| albumArt | string | yes | Artwork URL |
| addedByUID | string | yes | UID that added the song |
| voteCount | integer | yes | Net vote total |
| moodTags | array<string> | yes | Mood labels |
| addedAt | timestamp | yes | Song insertion time |

#### `sessions/{sessionId}/messages` sub-collection

| Field | Type | Required | Notes |
|---|---|---|---|
| senderUID | string | yes | Message sender UID |
| senderName | string | yes | Message sender display name |
| text | string | yes | Message text |
| reaction | string (nullable) | no | Optional emoji reaction |
| sentAt | timestamp | yes | Message timestamp |

## Seed Data Checklist

Create at least one seed document in:
- `users`
- `sessions`
- `sessions/{sessionId}/tracks`
- `sessions/{sessionId}/messages`

This ensures the structure is visible in Firestore during development and grading.
