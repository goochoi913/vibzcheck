import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../widgets/spotify_search_sheet.dart';
import '../../widgets/track_card.dart';
import '../../widgets/vote_button.dart';

class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final session = sessionProvider.currentSession;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Playlist')),
        body: const Center(
          child: Text(
            'Join or create a room from Home to start building a playlist.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Playlist')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          SpotifySearchSheet.show(
            context: context,
            sessionId: session.sessionId,
            onTrackSelected: (track) {},
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Song'),
      ),
      body: sessionProvider.tracks.isEmpty
          ? const Center(child: Text('No tracks yet. Add a song from Spotify.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sessionProvider.tracks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final track = sessionProvider.tracks[index];
                return Row(
                  children: [
                    Expanded(
                      child: TrackCard(
                        trackName: track.trackName,
                        artistName: track.artistName,
                      ),
                    ),
                    const SizedBox(width: 8),
                    VoteButton(votes: track.voteCount, onPressed: () {}),
                  ],
                );
              },
            ),
    );
  }
}
