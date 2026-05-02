import 'package:cloud_firestore/cloud_firestore.dart';

class TrackModel {
  const TrackModel({
    required this.trackId,
    required this.spotifyTrackId,
    required this.trackName,
    required this.artistName,
    required this.albumArt,
    this.previewUrl,
    required this.addedByUID,
    this.voteCount = 0,
    required this.moodTags,
    required this.addedAt,
  });

  final String trackId;
  final String spotifyTrackId;
  final String trackName;
  final String artistName;
  final String albumArt;
  final String? previewUrl;
  final String addedByUID;
  final int voteCount;
  final List<String> moodTags;
  final DateTime addedAt;

  factory TrackModel.fromMap(
    Map<String, dynamic> map, {
    required String trackId,
  }) {
    return TrackModel(
      trackId: trackId,
      spotifyTrackId: (map['spotifyTrackId'] as String?) ?? '',
      trackName: (map['trackName'] as String?) ?? '',
      artistName: (map['artistName'] as String?) ?? '',
      albumArt: (map['albumArt'] as String?) ?? '',
      previewUrl: map['previewUrl'] as String?,
      addedByUID: (map['addedByUID'] as String?) ?? '',
      voteCount: (map['voteCount'] as int?) ?? 0,
      moodTags: List<String>.from(map['moodTags'] as List? ?? const []),
      addedAt: _parseDateTime(map['addedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'spotifyTrackId': spotifyTrackId,
      'trackName': trackName,
      'artistName': artistName,
      'albumArt': albumArt,
      'previewUrl': previewUrl,
      'addedByUID': addedByUID,
      'voteCount': voteCount,
      'moodTags': moodTags,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }

  TrackModel copyWith({
    String? trackId,
    String? spotifyTrackId,
    String? trackName,
    String? artistName,
    String? albumArt,
    String? previewUrl,
    bool clearPreviewUrl = false,
    String? addedByUID,
    int? voteCount,
    List<String>? moodTags,
    DateTime? addedAt,
  }) {
    return TrackModel(
      trackId: trackId ?? this.trackId,
      spotifyTrackId: spotifyTrackId ?? this.spotifyTrackId,
      trackName: trackName ?? this.trackName,
      artistName: artistName ?? this.artistName,
      albumArt: albumArt ?? this.albumArt,
      previewUrl: clearPreviewUrl ? null : (previewUrl ?? this.previewUrl),
      addedByUID: addedByUID ?? this.addedByUID,
      voteCount: voteCount ?? this.voteCount,
      moodTags: moodTags ?? this.moodTags,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
