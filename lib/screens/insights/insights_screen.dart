import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../firebase/firestore_service.dart';
import '../../models/session_model.dart';
import '../../models/track_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  SessionModel? _session;
  List<TrackModel> _tracks = const <TrackModel>[];
  Future<UserModel?>? _hostFuture;

  bool _isSnapshotLoading = true;
  bool _isRecommendationsLoading = false;
  String? _recommendationsError;
  List<_RecommendationTrack> _recommendations = const <_RecommendationTrack>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final sessionProvider = context.read<SessionProvider>();
    final session = sessionProvider.currentSession;
    final tracks = List<TrackModel>.from(sessionProvider.tracks);

    setState(() {
      _session = session;
      _tracks = tracks;
      _hostFuture = session == null
          ? null
          : FirestoreService.instance.getUser(session.hostUID);
      _isSnapshotLoading = false;
    });

    if (session != null) {
      _refreshRecommendations();
    }
  }

  Future<void> _refreshRecommendations() async {
    final session = _session;
    if (session == null) return;

    setState(() {
      _isRecommendationsLoading = true;
      _recommendationsError = null;
    });

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('getRecommendations');
      final response = await callable.call(<String, dynamic>{
        'sessionId': session.sessionId,
      });

      final raw = response.data;
      final rawItems = raw is List
          ? raw
          : (raw is Map<String, dynamic> && raw['result'] is List)
          ? raw['result'] as List
          : const <dynamic>[];

      final parsed = rawItems
          .whereType<Map>()
          .map(
            (item) =>
                _RecommendationTrack.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _recommendations = parsed;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recommendationsError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRecommendationsLoading = false;
        });
      }
    }
  }

  Future<void> _addRecommendationToQueue(_RecommendationTrack item) async {
    final session = _session;
    final currentUser = context.read<AuthProvider>().currentUser;
    if (session == null || currentUser == null) return;

    final track = TrackModel(
      trackId: '',
      spotifyTrackId: item.trackId,
      trackName: item.trackName,
      artistName: item.artistName,
      albumArt: item.albumArtUrl,
      addedByUID: currentUser.uid,
      voteCount: 0,
      moodTags: const <String>[],
      addedAt: DateTime.now(),
    );

    await FirestoreService.instance.addTrack(
      sessionId: session.sessionId,
      track: track,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Added ${item.trackName} to queue')));
  }

  Map<String, int> _buildMoodFrequency() {
    final frequency = <String, int>{};
    for (final track in _tracks) {
      for (final tag in track.moodTags) {
        final normalized = tag.trim();
        if (normalized.isEmpty) continue;
        frequency[normalized] = (frequency[normalized] ?? 0) + 1;
      }
    }
    return frequency;
  }

  List<TrackModel> _topVotedTracks() {
    final sorted = List<TrackModel>.from(_tracks)
      ..sort((a, b) {
        final voteCompare = b.voteCount.compareTo(a.voteCount);
        if (voteCompare != 0) return voteCompare;
        return a.addedAt.compareTo(b.addedAt);
      });
    return sorted.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSnapshotLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = _session;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.music_note_rounded,
                  size: 84,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Start or join a session to see insights.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final moodFrequency = _buildMoodFrequency();
    final sortedMoodEntries = moodFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTracks = _topVotedTracks();

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Section(
            title: 'Session Summary',
            child: FutureBuilder<UserModel?>(
              future: _hostFuture,
              builder: (context, snapshot) {
                final hostName = snapshot.data?.displayName.isNotEmpty == true
                    ? snapshot.data!.displayName
                    : session.hostUID;
                final ageMinutes = DateTime.now()
                    .difference(session.createdAt)
                    .inMinutes;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryRow('Session', session.sessionName),
                    _summaryRow('Host', hostName),
                    _summaryRow('Tracks', '${_tracks.length}'),
                    _summaryRow(
                      'Collaborators',
                      '${session.collaborators.length}',
                    ),
                    _summaryRow(
                      'Age',
                      '${ageMinutes < 0 ? 0 : ageMinutes} min',
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Mood Profile',
            child: sortedMoodEntries.isEmpty
                ? Text(
                    'No mood tags yet. Add songs and tag them first.',
                    style: TextStyle(color: Colors.grey.shade400),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: sortedMoodEntries.asMap().entries.map((entry) {
                        final isTop = entry.key == 0;
                        final mood = entry.value.key;
                        final count = entry.value.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Chip(
                            backgroundColor: isTop
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white.withValues(alpha: 0.08),
                            label: Text(
                              '$mood · $count',
                              style: TextStyle(
                                fontSize: isTop ? 17 : 14,
                                fontWeight: isTop
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isTop
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Colors.grey.shade200,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Top Voted Tracks',
            child: topTracks.isEmpty
                ? Text(
                    'No tracks in this session yet.',
                    style: TextStyle(color: Colors.grey.shade400),
                  )
                : Column(
                    children: topTracks
                        .map(
                          (track) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TopTrackTile(track: track),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          _Section(
            titleWidget: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Vibes You Might Like',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isRecommendationsLoading
                      ? null
                      : _refreshRecommendations,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            child: _isRecommendationsLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _recommendationsError != null
                ? Text(
                    'Unable to load recommendations: $_recommendationsError',
                    style: TextStyle(color: Colors.red.shade300),
                  )
                : _recommendations.isEmpty
                ? Text(
                    'No recommendations yet. Add more tagged songs and refresh.',
                    style: TextStyle(color: Colors.grey.shade400),
                  )
                : SizedBox(
                    height: 236,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recommendations.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = _recommendations[index];
                        return _RecommendationCard(
                          track: item,
                          onAddToQueue: () => _addRecommendationToQueue(item),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            child: Text(label, style: TextStyle(color: Colors.grey.shade400)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.title, this.titleWidget});

  final String? title;
  final Widget? titleWidget;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget ??
              Text(
                title ?? '',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TopTrackTile extends StatelessWidget {
  const _TopTrackTile({required this.track});

  final TrackModel track;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: track.albumArt,
              width: 46,
              height: 46,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                width: 46,
                height: 46,
                color: Colors.white10,
                alignment: Alignment.center,
                child: const Icon(Icons.music_note),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${track.voteCount} votes',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.track, required this.onAddToQueue});

  final _RecommendationTrack track;
  final VoidCallback onAddToQueue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: track.albumArtUrl,
                  width: double.infinity,
                  height: 112,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    width: double.infinity,
                    height: 112,
                    color: Colors.white10,
                    alignment: Alignment.center,
                    child: const Icon(Icons.music_note),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                track.trackName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                track.artistName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: onAddToQueue,
                  child: const Text('Add to Queue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationTrack {
  const _RecommendationTrack({
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

  factory _RecommendationTrack.fromMap(Map<String, dynamic> map) {
    return _RecommendationTrack(
      trackId: (map['trackId'] as String?) ?? '',
      trackName: (map['trackName'] as String?) ?? 'Unknown Track',
      artistName: (map['artistName'] as String?) ?? 'Unknown Artist',
      albumArtUrl: (map['albumArtUrl'] as String?) ?? '',
      previewUrl: map['previewUrl'] as String?,
    );
  }
}
