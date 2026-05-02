import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/track_model.dart';
import 'preview_play_button.dart';
import 'vote_button.dart';

class TrackCard extends StatelessWidget {
  const TrackCard({
    super.key,
    required this.track,
    required this.isHost,
    required this.currentVoteCount,
    required this.hasVoted,
    required this.votePulseToken,
    this.onVote,
    this.onDelete,
    this.onLongPress,
  });

  final TrackModel track;
  final bool isHost;
  final int currentVoteCount;
  final bool hasVoted;
  final int votePulseToken;
  final VoidCallback? onVote;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cardContent = Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: CachedNetworkImage(
                imageUrl: track.albumArt,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.white12,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.white12,
                  alignment: Alignment.center,
                  child: const Icon(Icons.music_note),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.trackName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  track.artistName,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
                const SizedBox(height: 2),
                PreviewPlayButton(
                  trackId: track.trackId,
                  previewUrl: track.previewUrl,
                ),
                if (track.moodTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: track.moodTags
                        .map(
                          (tag) => Chip(
                            visualDensity: VisualDensity.compact,
                            side: BorderSide.none,
                            backgroundColor: _moodColor(tag),
                            label: Text(
                              tag,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          VoteButton(
            votes: currentVoteCount,
            hasVoted: hasVoted,
            pulseToken: votePulseToken,
            onPressed: onVote,
          ),
          if (isHost)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Delete Track',
            ),
        ],
      ),
    );

    return Card(
      child: onLongPress == null
          ? cardContent
          : InkWell(
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(12),
              child: cardContent,
            ),
    );
  }

  Color _moodColor(String tag) {
    final palette = <Color>[
      const Color(0xFFF8BBD0),
      const Color(0xFFB3E5FC),
      const Color(0xFFC8E6C9),
      const Color(0xFFFFE0B2),
      const Color(0xFFD1C4E9),
      const Color(0xFFFFCDD2),
      const Color(0xFFDCEDC8),
    ];
    final hash = tag.runes.fold<int>(0, (sum, rune) => sum + rune);
    return palette[hash % palette.length];
  }
}
