import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../firebase/firestore_service.dart';
import '../models/track_model.dart';
import '../providers/auth_provider.dart';
import '../utils/mood_tags.dart';

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
  static const int _maxQueryLength = 120;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<_SpotifyResult> _results = const [];
  bool _isLoading = false;
  String? _errorMessage;

  _SpotifyResult? _pendingSelection;
  final Set<String> _selectedMoodTags = <String>{};

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
    final trimmed = query.trim().substring(
      0,
      query.trim().length > _maxQueryLength
          ? _maxQueryLength
          : query.trim().length,
    );
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
          : (raw is Map<String, dynamic> && raw['result'] is List)
          ? raw['result'] as List
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

  void _startMoodStep(_SpotifyResult result) {
    setState(() {
      _pendingSelection = result;
      _selectedMoodTags.clear();
    });
  }

  void _toggleMoodTag(String tag) {
    setState(() {
      if (_selectedMoodTags.contains(tag)) {
        _selectedMoodTags.remove(tag);
      } else {
        _selectedMoodTags.add(tag);
      }
    });
  }

  Future<void> _saveTrackWithMoodTags() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    final selected = _pendingSelection;
    if (currentUser == null || selected == null) return;

    final track = TrackModel(
      trackId: '',
      spotifyTrackId: selected.trackId,
      trackName: selected.trackName,
      artistName: selected.artistName,
      albumArt: selected.albumArtUrl,
      previewUrl: selected.previewUrl,
      addedByUID: currentUser.uid,
      voteCount: 0,
      moodTags: _selectedMoodTags.toList(),
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
          child: _pendingSelection == null
              ? _buildSearchStep(scrollController)
              : _buildMoodStep(),
        );
      },
    );
  }

  Widget _buildSearchStep(ScrollController scrollController) {
    return Column(
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
            maxLength: _maxQueryLength,
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
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              : _results.isEmpty
              ? const Center(child: Text('Start typing to search for songs.'))
              : ListView.separated(
                  controller: scrollController,
                  itemCount: _results.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    return ListTile(
                      onTap: () => _startMoodStep(item),
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
                            errorWidget: (context, url, error) => Container(
                              color: Colors.white12,
                              alignment: Alignment.center,
                              child: const Icon(Icons.music_note),
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        item.trackName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
    );
  }

  Widget _buildMoodStep() {
    final selected = _pendingSelection;
    if (selected == null) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _pendingSelection = null;
                    _selectedMoodTags.clear();
                  });
                },
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Tag this track',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            selected.trackName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          Text(
            selected.artistName,
            style: TextStyle(color: Colors.grey.shade400),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kMoodTagOptions.map((tag) {
              final selected = _selectedMoodTags.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: selected,
                onSelected: (_) => _toggleMoodTag(tag),
                selectedColor: colorScheme.primary.withValues(alpha: 0.95),
                checkmarkColor: colorScheme.onPrimary,
                labelStyle: TextStyle(
                  color: selected
                      ? colorScheme.onPrimary
                      : Colors.grey.shade200,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: selected
                      ? colorScheme.primary
                      : Colors.white.withValues(alpha: 0.35),
                ),
                backgroundColor: Colors.transparent,
              );
            }).toList(),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _saveTrackWithMoodTags,
            child: const Text('Done'),
          ),
        ],
      ),
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
