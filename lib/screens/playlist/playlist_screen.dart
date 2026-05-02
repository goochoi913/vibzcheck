import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../firebase/firestore_service.dart';
import '../../models/track_model.dart';
import '../../models/user_model.dart';
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
    final userUID = currentUser?.uid;

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
            if (isHost)
              Text(
                'Collaborators: ${session.collaborators.length}',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
              )
            else
              FutureBuilder<UserModel?>(
                future: FirestoreService.instance.getUser(session.hostUID),
                builder: (context, snapshot) {
                  final hostName = snapshot.data?.displayName.isNotEmpty == true
                      ? snapshot.data!.displayName
                      : session.hostUID;
                  return Text(
                    'Hosted by $hostName',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    ),
                  );
                },
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () =>
                _showSessionShareDialog(context, session.sessionId),
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
      body: Column(
        children: [
          if (sessionProvider.errorMessage != null)
            Container(
              width: double.infinity,
              color: Colors.red.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                sessionProvider.errorMessage!,
                style: TextStyle(color: Colors.red.shade200),
              ),
            ),
          Expanded(
            child: _AnimatedTrackList(
              tracks: sessionProvider.tracks,
              isHost: isHost,
              votedTrackIds: sessionProvider.votedTrackIds,
              votePulseTokenForTrack: sessionProvider.votePulseTokenForTrack,
              onVote: (track) {
                if (userUID == null) return;
                sessionProvider.voteOnTrack(
                  trackId: track.trackId,
                  voterUID: userUID,
                );
              },
              onDelete: (track) {
                FirestoreService.instance.deleteTrack(
                  sessionId: session.sessionId,
                  trackId: track.trackId,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTrackList extends StatelessWidget {
  const _AnimatedTrackList({
    required this.tracks,
    required this.isHost,
    required this.votedTrackIds,
    required this.votePulseTokenForTrack,
    required this.onVote,
    required this.onDelete,
  });

  final List<TrackModel> tracks;
  final bool isHost;
  final Set<String> votedTrackIds;
  final int Function(String trackId) votePulseTokenForTrack;
  final ValueChanged<TrackModel> onVote;
  final ValueChanged<TrackModel> onDelete;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return const Center(
        child: Text('No tracks yet. Tap Add Song to build your queue.'),
      );
    }

    final signature = tracks
        .map((track) => '${track.trackId}:${track.voteCount}')
        .join('|');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: ListView.builder(
        key: ValueKey<String>(signature),
        padding: const EdgeInsets.all(14),
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          final hasVoted = votedTrackIds.contains(track.trackId);

          return TweenAnimationBuilder<double>(
            key: ValueKey<String>('${track.trackId}-${track.voteCount}'),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            tween: Tween<double>(begin: 0.5, end: 1),
            builder: (context, opacity, child) {
              return Opacity(opacity: opacity, child: child);
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TrackCard(
                track: track,
                isHost: isHost,
                currentVoteCount: track.voteCount,
                hasVoted: hasVoted,
                votePulseToken: votePulseTokenForTrack(track.trackId),
                onVote: () => onVote(track),
                onDelete: isHost ? () => onDelete(track) : null,
              ),
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
    builder: (dialogContext) => AlertDialog(
      title: const Text('Invite Collaborators'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Room ID'),
          const SizedBox(height: 8),
          Text(
            sessionId,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: sessionId));
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Room ID copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy to Clipboard'),
          ),
          const SizedBox(height: 16),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.qr_code_2, size: 42),
                SizedBox(height: 6),
                Text('QR coming soon'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
