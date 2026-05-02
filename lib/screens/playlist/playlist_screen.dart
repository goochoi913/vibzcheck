import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../firebase/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/spotify_search_sheet.dart';
import '../../widgets/track_card.dart';

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
          child: Text('Join or create a room from Home to start the playlist.'),
        ),
      );
    }

    final currentUser = context.watch<AuthProvider>().currentUser;
    final isHost = currentUser?.uid == session.hostUID;

    if (isHost) {
      return _HostPlaylistView();
    }

    return _CollaboratorPlaylistView();
  }
}

class _HostPlaylistView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final session = sessionProvider.currentSession!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {},
          icon: const Icon(Icons.group_outlined),
          tooltip: 'Collaborators',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.sessionName),
            Text(
              'Collaborators: ${session.collaborators.length}',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showSessionShareDialog(context, session.sessionId),
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Room',
          ),
        ],
      ),
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
      body: StreamBuilder<List<dynamic>>(
        stream: Stream<List<dynamic>>.value(sessionProvider.tracks),
        builder: (context, snapshot) {
          final tracks = sessionProvider.tracks;

          if (tracks.isEmpty) {
            return const Center(
              child: Text('No tracks yet. Tap Add Song to build your queue.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TrackCard(
                  track: track,
                  isHost: true,
                  currentVoteCount: track.voteCount,
                  onVote: () {},
                  onDelete: () {
                    FirestoreService.instance.deleteTrack(
                      sessionId: session.sessionId,
                      trackId: track.trackId,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CollaboratorPlaylistView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final session = sessionProvider.currentSession!;

    return Scaffold(
      appBar: AppBar(title: Text(session.sessionName)),
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
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: sessionProvider.tracks.length,
        itemBuilder: (context, index) {
          final track = sessionProvider.tracks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TrackCard(
              track: track,
              isHost: false,
              currentVoteCount: track.voteCount,
              onVote: () {},
            ),
          );
        },
      ),
    );
  }
}

Future<void> _showSessionShareDialog(BuildContext context, String sessionId) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Share Room'),
      content: Text('Session ID: $sessionId'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
