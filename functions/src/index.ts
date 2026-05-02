import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { defineSecret } from "firebase-functions/params";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

const spotifyTokenUrl = "https://accounts.spotify.com/api/token";
const spotifyApiBase = "https://api.spotify.com/v1";
const db = getFirestore(initializeApp());

type SpotifySearchTrack = {
  trackId: string;
  trackName: string;
  artistName: string;
  albumArtUrl: string;
  previewUrl: string | null;
};

type SpotifyConfig = {
  clientId: string;
  clientSecret: string;
};

type SpotifyRecommendationsResponse = {
  tracks?: Array<{
    id?: string;
    name?: string;
    artists?: Array<{ name?: string }>;
    album?: { images?: Array<{ url?: string }> };
    preview_url?: string | null;
  }>;
};

const moodToSpotifyGenre: Record<string, string[]> = {
  chill: ["chill", "ambient", "acoustic"],
  hype: ["dance", "edm", "hip-hop"],
  sad: ["acoustic", "blues", "piano"],
  happy: ["pop", "dance", "funk"],
  focused: ["study", "classical", "ambient"],
  party: ["party", "dance", "electro"],
  throwback: ["disco", "funk", "old-school"],
  indie: ["indie", "alternative", "rock"],
};

const spotifyClientId = defineSecret("SPOTIFY_CLIENT_ID");
const spotifyClientSecret = defineSecret("SPOTIFY_CLIENT_SECRET");

function getSpotifyConfig(): SpotifyConfig {
  const clientId = spotifyClientId.value().trim();
  const clientSecret = spotifyClientSecret.value().trim();

  if (!clientId || !clientSecret) {
    throw new HttpsError(
      "failed-precondition",
      "Spotify credentials are missing from functions config.",
    );
  }

  return { clientId, clientSecret };
}

async function getSpotifyAccessToken(): Promise<string> {
  const { clientId, clientSecret } = getSpotifyConfig();
  const credentials = Buffer.from(`${clientId}:${clientSecret}`).toString(
    "base64",
  );

  const response = await fetch(spotifyTokenUrl, {
    method: "POST",
    headers: {
      Authorization: `Basic ${credentials}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new HttpsError(
      "internal",
      `Spotify token request failed: ${errorText}`,
    );
  }

  const body = (await response.json()) as { access_token?: string };
  if (!body.access_token) {
    throw new HttpsError(
      "internal",
      "Spotify token response did not include access_token.",
    );
  }

  return body.access_token;
}

function simplifySpotifyTrack(item: {
  id?: string;
  name?: string;
  artists?: Array<{ name?: string }>;
  album?: { images?: Array<{ url?: string }> };
  preview_url?: string | null;
}): SpotifySearchTrack | null {
  if (!item.id || !item.name) {
    return null;
  }

  return {
    trackId: item.id,
    trackName: item.name,
    artistName:
      item.artists
        ?.map((artist) => artist.name)
        .filter((name): name is string => Boolean(name))
        .join(", ") ?? "Unknown Artist",
    albumArtUrl: item.album?.images?.[0]?.url ?? "",
    previewUrl: item.preview_url ?? null,
  };
}

export const searchSpotifyTracks = onCall(
  {
    region: "us-central1",
    invoker: "public",
    secrets: [spotifyClientId, spotifyClientSecret],
  },
  async (request) => {
    const query = (request.data?.query as string | undefined ?? "").trim();

    if (!query || query.length < 2) {
      throw new HttpsError(
        "invalid-argument",
        "query must be at least 2 characters.",
      );
    }

    const token = await getSpotifyAccessToken();
    const url = new URL(`${spotifyApiBase}/search`);
    url.searchParams.set("q", query);
    url.searchParams.set("type", "track");
    // This app credential currently supports limits up to 10.
    url.searchParams.set("limit", "10");

    const response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new HttpsError("internal", `Spotify search failed: ${errorText}`);
    }

    const body = (await response.json()) as {
      tracks?: {
        items?: Array<{
          id?: string;
          name?: string;
          artists?: Array<{ name?: string }>;
          album?: { images?: Array<{ url?: string }> };
          preview_url?: string | null;
        }>;
      };
    };

    const tracks: SpotifySearchTrack[] = (body.tracks?.items ?? [])
      .map((item) => simplifySpotifyTrack(item))
      .filter((item): item is SpotifySearchTrack => item !== null);

    return tracks;
  },
);

export const getRecommendations = onCall(
  {
    region: "us-central1",
    invoker: "public",
    secrets: [spotifyClientId, spotifyClientSecret],
  },
  async (request) => {
    const sessionId = (request.data?.sessionId as string | undefined ?? "").trim();

    if (!sessionId) {
      throw new HttpsError("invalid-argument", "sessionId is required.");
    }

    const tracksSnapshot = await db
      .collection("sessions")
      .doc(sessionId)
      .collection("tracks")
      .get();

    if (tracksSnapshot.empty) {
      return [] as SpotifySearchTrack[];
    }

    const tagFrequency = new Map<string, number>();
    for (const doc of tracksSnapshot.docs) {
      const moodTags = doc.data().moodTags as string[] | undefined;
      for (const tag of moodTags ?? []) {
        const normalized = tag.trim().toLowerCase();
        if (!normalized) continue;
        tagFrequency.set(normalized, (tagFrequency.get(normalized) ?? 0) + 1);
      }
    }

    const topTags = [...tagFrequency.entries()]
      .sort((a, b) => b[1] - a[1])
      .map(([tag]) => tag)
      .slice(0, 2);

    const seedGenres = new Set<string>();
    for (const tag of topTags) {
      for (const genre of moodToSpotifyGenre[tag] ?? []) {
        seedGenres.add(genre);
      }
      if (seedGenres.size >= 2) break;
    }
    if (seedGenres.size == 0) {
      seedGenres.add("pop");
      seedGenres.add("indie");
    } else if (seedGenres.size == 1) {
      seedGenres.add("dance");
    }

    const token = await getSpotifyAccessToken();
    const url = new URL(`${spotifyApiBase}/recommendations`);
    url.searchParams.set("seed_genres", [...seedGenres].slice(0, 2).join(","));
    url.searchParams.set("limit", "5");
    url.searchParams.set("market", "US");

    const response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error("Spotify recommendations request failed", {
        sessionId,
        topTags,
        seedGenres: [...seedGenres],
        status: response.status,
        errorText,
      });
      throw new HttpsError(
        "internal",
        `Spotify recommendations failed: ${errorText}`,
      );
    }

    const body = (await response.json()) as SpotifyRecommendationsResponse;
    const recommendations = (body.tracks ?? [])
      .map((item) => simplifySpotifyTrack(item))
      .filter((item): item is SpotifySearchTrack => item !== null)
      .slice(0, 5);

    return recommendations;
  },
);

export const getSpotifyTrackDetails = onCall(
  {
    region: "us-central1",
    invoker: "public",
    secrets: [spotifyClientId, spotifyClientSecret],
  },
  async (request) => {
    const spotifyTrackId = (
      request.data?.spotifyTrackId as string | undefined ?? ""
    ).trim();

    if (!spotifyTrackId) {
      throw new HttpsError("invalid-argument", "spotifyTrackId is required.");
    }

    const token = await getSpotifyAccessToken();

    const trackResponse = await fetch(
      `${spotifyApiBase}/tracks/${spotifyTrackId}`,
      {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      },
    );

    if (!trackResponse.ok) {
      const errorText = await trackResponse.text();
      throw new HttpsError(
        "internal",
        `Spotify track details failed: ${errorText}`,
      );
    }

    const track = await trackResponse.json();

    // The audio-features endpoint may be unavailable for some Spotify app modes.
    let audioFeatures: unknown = null;
    try {
      const audioResponse = await fetch(
        `${spotifyApiBase}/audio-features/${spotifyTrackId}`,
        {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        },
      );

      if (audioResponse.ok) {
        audioFeatures = await audioResponse.json();
      }
    } catch (error) {
      logger.warn("Audio features lookup failed", error as object);
    }

    return {
      trackId: track.id,
      trackName: track.name,
      artistName:
        (track.artists as Array<{ name?: string }> | undefined)
          ?.map((artist) => artist.name)
          .filter((name): name is string => Boolean(name))
          .join(", ") ?? "Unknown Artist",
      albumArtUrl: (
        track.album as { images?: Array<{ url?: string }> } | undefined
      )?.images?.[0]?.url,
      previewUrl: (track.preview_url as string | undefined) ?? null,
      durationMs: track.duration_ms,
      popularity: track.popularity,
      explicit: track.explicit,
      audioFeatures,
    };
  },
);

export const notifySessionEvent = onDocumentCreated(
  {
    region: "us-central1",
    document: "sessions/{sessionId}/tracks/{trackId}",
  },
  async (event) => {
    const data = event.data?.data();
    const sessionId = event.params.sessionId;
    const trackId = event.params.trackId;

    if (!data || !sessionId || !trackId) {
      return;
    }

    const trackName = (data.trackName as string | undefined)?.trim() || "New Track";
    const artistName =
      (data.artistName as string | undefined)?.trim() || "Unknown Artist";

    const sessionSnapshot = await db.collection("sessions").doc(sessionId).get();
    if (!sessionSnapshot.exists) {
      logger.warn("Session not found for notifySessionEvent", { sessionId, trackId });
      return;
    }

    const sessionData = sessionSnapshot.data() ?? {};
    const sessionName = (sessionData.sessionName as string | undefined)?.trim() || "session";
    const collaborators = (sessionData.collaborators as string[] | undefined) ?? [];

    if (collaborators.length === 0) {
      return;
    }

    const userSnapshots = await Promise.all(
      collaborators.map((uid) => db.collection("users").doc(uid).get()),
    );

    const tokens = new Set<string>();
    for (const userSnapshot of userSnapshots) {
      const token = userSnapshot.data()?.fcmToken as string | undefined;
      if (token && token.trim().length > 0) {
        tokens.add(token.trim());
      }
    }

    if (tokens.size === 0) {
      logger.info("No collaborator FCM tokens for session event", { sessionId, trackId });
      return;
    }

    const response = await getMessaging().sendEachForMulticast({
      tokens: [...tokens],
      notification: {
        title: "New Song Added",
        body: `${trackName} by ${artistName} was added to ${sessionName}`,
      },
      data: {
        sessionId,
        trackId,
        screen: "playlist",
      },
      android: {
        priority: "high",
      },
    });

    logger.info("notifySessionEvent completed", {
      sessionId,
      trackId,
      tokenCount: tokens.size,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });
  },
);
