import 'dart:async';

import 'package:just_audio/just_audio.dart';

class PreviewAudioController {
  PreviewAudioController._();

  static final AudioPlayer _player = AudioPlayer();
  static String? _activeTrackId;
  static final StreamController<void> _eventsController =
      StreamController<void>.broadcast();
  static bool _initialized = false;

  static Stream<void> get events {
    _ensureInitialized();
    return _eventsController.stream;
  }

  static String? get activeTrackId {
    _ensureInitialized();
    return _activeTrackId;
  }

  static bool get isPlaying {
    _ensureInitialized();
    return _player.playing;
  }

  static Future<void> toggle({
    required String trackId,
    required String? previewUrl,
  }) async {
    _ensureInitialized();

    if (previewUrl == null || previewUrl.trim().isEmpty) {
      return;
    }

    if (_activeTrackId == trackId) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      _emit();
      return;
    }

    await _player.stop();
    _activeTrackId = trackId;
    _emit();

    try {
      await _player.setUrl(previewUrl);
      await _player.play();
    } catch (_) {
      _activeTrackId = null;
      _emit();
    }
  }

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _activeTrackId = null;
      }
      _emit();
    });
  }

  static void _emit() {
    if (!_eventsController.isClosed) {
      _eventsController.add(null);
    }
  }
}
