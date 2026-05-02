import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../firebase/firestore_service.dart';
import '../models/track_model.dart';
import '../providers/auth_provider.dart';

class SpotifySearchSheet extends StatefulWidget {
  const SpotifySearchSheet({
    super.key,
    required this.sessionId,
    required this.onTrackSelected,
  });

  final String sessionId;
  final ValueChanged<TrackModel> onTrackSelected;

  static Future<void> show({
    required BuildContext context,
    required String sessionId,
    required ValueChanged<TrackModel> onTrackSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SpotifySearchSheet(
          sessionId: sessionId,
          onTrackSelected: onTrackSelected,
        );
      },
    );
  }

  @override
  State<SpotifySearchSheet> createState() => _SpotifySearchSheetState();
}

class _SpotifySearchSheetState extends State<SpotifySearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<_SpotifyResult> _results = const [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchTracks(query);
    });
  }

  Future<void> _searchTracks(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'searchSpotifyTracks',
      );
      final response = await callable.call(<String, dynamic>{'query': trimmed});

      final raw = response.data;
      final rawItems = raw is List
          ? raw
          : (raw is Map<String, dynamic> && raw['tracks'] is List)
          ? raw['tracks'] as List
          : const [];

      final parsed = rawItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(_SpotifyResult.fromMap)
          .toList();

      if (!mounted) return;
      setState(() {
        _results = parsed;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _selectTrack(_SpotifyResult result) async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    final track = TrackModel(
      trackId: '',
      spotifyTrackId: result.trackId,
      trackName: result.trackName,
      artistName: result.artistName,
      albumArt: result.albumArtUrl,
      addedByUID: currentUser.uid,
      voteCount: 0,
      moodTags: const [],
      addedAt: DateTime.now(),
    );

    await FirestoreService.instance.addTrack(
      sessionId: widget.sessionId,
      track: track,
    );

    if (!mounted) return;
    widget.onTrackSelected(track);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade500,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onQueryChanged,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Search Spotify tracks',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Search failed: $_errorMessage',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _results.isEmpty
                    ? const Center(
                        child: Text('Start typing to search for songs.'),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: _results.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return ListTile(
                            onTap: () => _selectTrack(item),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: CachedNetworkImage(
                                  imageUrl: item.albumArtUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.white12,
                                    alignment: Alignment.center,
                                    child: const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: Colors.white12,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.music_note),
                                      ),
                                ),
                              ),
                            ),
                            title: Text(
                              item.trackName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              item.artistName,
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpotifyResult {
  const _SpotifyResult({
    required this.trackId,
    required this.trackName,
    required this.artistName,
    required this.albumArtUrl,
    required this.previewUrl,
  });

  final String trackId;
  final String trackName;
  final String artistName;
  final String albumArtUrl;
  final String? previewUrl;

  factory _SpotifyResult.fromMap(Map<String, dynamic> map) {
    return _SpotifyResult(
      trackId: (map['trackId'] as String?) ?? (map['id'] as String? ?? ''),
      trackName:
          (map['trackName'] as String?) ?? (map['name'] as String? ?? ''),
      artistName:
          (map['artistName'] as String?) ??
          (map['artist'] as String? ?? 'Unknown Artist'),
      albumArtUrl:
          (map['albumArtUrl'] as String?) ?? (map['albumArt'] as String? ?? ''),
      previewUrl: map['previewUrl'] as String?,
    );
  }
}
