import 'package:flutter/material.dart';

import '../utils/preview_audio_controller.dart';

class PreviewPlayButton extends StatelessWidget {
  const PreviewPlayButton({
    super.key,
    required this.trackId,
    required this.previewUrl,
  });

  final String trackId;
  final String? previewUrl;

  @override
  Widget build(BuildContext context) {
    final hasPreview = (previewUrl ?? '').trim().isNotEmpty;

    return StreamBuilder<void>(
      stream: PreviewAudioController.events,
      builder: (context, snapshot) {
        final isCurrentTrack = PreviewAudioController.activeTrackId == trackId;
        final isPlaying = isCurrentTrack && PreviewAudioController.isPlaying;

        return IconButton(
          onPressed: hasPreview
              ? () => PreviewAudioController.toggle(
                  trackId: trackId,
                  previewUrl: previewUrl,
                )
              : null,
          tooltip: hasPreview ? 'Play 30s preview' : 'Preview unavailable',
          icon: Icon(
            hasPreview
                ? (isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill)
                : Icons.music_off,
            color: hasPreview
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade600,
          ),
        );
      },
    );
  }
}
