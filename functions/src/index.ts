import * as functions from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

const spotifyTokenUrl = "https://accounts.spotify.com/api/token";
const spotifyApiBase = "https://api.spotify.com/v1";

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

function getSpotifyConfig(): SpotifyConfig {
  const config = functions.config().spotify as
    | { client_id?: string; client_secret?: string }
    | undefined;

  const clientId = config?.client_id?.trim() ?? "";
  const clientSecret = config?.client_secret?.trim() ?? "";

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

export const searchSpotifyTracks = onCall(
  { region: "us-central1", invoker: "public" },
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
    url.searchParams.set("limit", "20");

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
      .filter((item) => item.id && item.name)
      .map((item) => ({
        trackId: item.id!,
        trackName: item.name!,
        artistName:
          item.artists
            ?.map((artist) => artist.name)
            .filter((name): name is string => Boolean(name))
            .join(", ") ?? "Unknown Artist",
        albumArtUrl: item.album?.images?.[0]?.url ?? "",
        previewUrl: item.preview_url ?? null,
      }));

    return tracks;
  },
);

export const getSpotifyTrackDetails = onCall(
  { region: "us-central1", invoker: "public" },
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
