import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firestore_service.dart';
import '../models/session_model.dart';
import '../models/track_model.dart';

class SessionProvider extends ChangeNotifier {
  SessionProvider({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService.instance;

  final FirestoreService _firestoreService;

  SessionModel? _currentSession;
  List<TrackModel> _tracks = const [];
  final Set<String> _votedTrackIds = <String>{};
  final Map<String, int> _votePulseTokens = <String, int>{};
  bool _newTrackAdded = false;
  TrackModel? _latestTrack;
  bool _hasReceivedInitialTrackSnapshot = false;

  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserUID;
  bool _isRefreshingVotes = false;

  StreamSubscription<SessionModel>? _sessionSubscription;
  StreamSubscription<List<TrackModel>>? _tracksSubscription;

  SessionModel? get currentSession => _currentSession;
  List<TrackModel> get tracks => _tracks;
  Set<String> get votedTrackIds => Set<String>.unmodifiable(_votedTrackIds);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get newTrackAdded => _newTrackAdded;
  TrackModel? get latestTrack => _latestTrack;

  int votePulseTokenForTrack(String trackId) => _votePulseTokens[trackId] ?? 0;

  Future<void> createSession({
    required String sessionName,
    required String hostUID,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    _currentUserUID = hostUID;

    try {
      final session = await _firestoreService.createSession(
        sessionName: sessionName,
        hostUID: hostUID,
      );
      await _listenToSession(session.sessionId);
    } catch (error) {
      _errorMessage = _friendlyError(error);
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> joinSession({
    required String sessionId,
    required String userUID,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    _currentUserUID = userUID;

    try {
      await _firestoreService.joinSession(
        sessionId: sessionId,
        userUID: userUID,
      );
      await _listenToSession(sessionId);
    } catch (error) {
      _errorMessage = _friendlyError(error);
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> leaveSession() async {
    await _cancelSubscriptions();
    _currentSession = null;
    _tracks = const [];
    _votedTrackIds.clear();
    _votePulseTokens.clear();
    _errorMessage = null;
    _currentUserUID = null;
    _newTrackAdded = false;
    _latestTrack = null;
    _hasReceivedInitialTrackSnapshot = false;
    notifyListeners();
  }

  Future<void> voteOnTrack({
    required String trackId,
    required String voterUID,
  }) async {
    final sessionId = _currentSession?.sessionId;
    if (sessionId == null) return;

    _errorMessage = null;

    if (_votedTrackIds.contains(trackId)) {
      _votedTrackIds.remove(trackId);
      notifyListeners();

      try {
        await _firestoreService.removeVote(
          sessionId: sessionId,
          trackId: trackId,
          voterUID: voterUID,
        );
      } catch (_) {
        _votedTrackIds.add(trackId);
        _errorMessage = 'Unable to remove vote. Please try again.';
        notifyListeners();
      }
      return;
    }

    _votedTrackIds.add(trackId);
    _votePulseTokens.update(trackId, (value) => value + 1, ifAbsent: () => 1);
    notifyListeners();

    try {
      await _firestoreService.voteOnTrack(
        sessionId: sessionId,
        trackId: trackId,
        voterUID: voterUID,
      );
    } on AlreadyVotedException catch (error) {
      _votedTrackIds.remove(trackId);
      _errorMessage = error.message;
      notifyListeners();
    } catch (_) {
      _votedTrackIds.remove(trackId);
      _errorMessage = 'Unable to register vote. Please try again.';
      notifyListeners();
    }
  }

  Future<void> _listenToSession(String sessionId) async {
    await _cancelSubscriptions();
    _hasReceivedInitialTrackSnapshot = false;
    _newTrackAdded = false;
    _latestTrack = null;

    _sessionSubscription = _firestoreService
        .getSession(sessionId)
        .listen(
          (session) {
            _currentSession = session;
            notifyListeners();
          },
          onError: (error) {
            _errorMessage = error.toString();
            notifyListeners();
          },
        );

    _tracksSubscription = _firestoreService
        .getTracksStream(sessionId)
        .listen(
          (tracks) {
            final previousTrackIds = _tracks
                .map((track) => track.trackId)
                .toSet();
            if (_hasReceivedInitialTrackSnapshot &&
                tracks.length > _tracks.length) {
              final newlyAdded = tracks.where(
                (track) => !previousTrackIds.contains(track.trackId),
              );
              if (newlyAdded.isNotEmpty) {
                _latestTrack = newlyAdded.first;
                _newTrackAdded = true;
              }
            }
            _tracks = tracks;
            _hasReceivedInitialTrackSnapshot = true;
            notifyListeners();
            unawaited(_refreshVotedTrackIdsForCurrentUser());
          },
          onError: (error) {
            _errorMessage = error.toString();
            notifyListeners();
          },
        );

    await _refreshVotedTrackIdsForCurrentUser();
  }

  Future<void> _refreshVotedTrackIdsForCurrentUser() async {
    final sessionId = _currentSession?.sessionId;
    final currentUserUID = _currentUserUID;

    if (sessionId == null || currentUserUID == null || _tracks.isEmpty) {
      if (_votedTrackIds.isNotEmpty) {
        _votedTrackIds.clear();
        notifyListeners();
      }
      return;
    }

    if (_isRefreshingVotes) return;
    _isRefreshingVotes = true;

    try {
      final checks = await Future.wait(
        _tracks.map(
          (track) => _firestoreService.hasUserVotedOnTrack(
            sessionId: sessionId,
            trackId: track.trackId,
            voterUID: currentUserUID,
          ),
        ),
      );

      final refreshed = <String>{};
      for (var i = 0; i < _tracks.length; i++) {
        if (checks[i]) {
          refreshed.add(_tracks[i].trackId);
        }
      }

      if (!setEquals(refreshed, _votedTrackIds)) {
        _votedTrackIds
          ..clear()
          ..addAll(refreshed);
        notifyListeners();
      }
    } finally {
      _isRefreshingVotes = false;
    }
  }

  Future<void> _cancelSubscriptions() async {
    await _sessionSubscription?.cancel();
    await _tracksSubscription?.cancel();
    _sessionSubscription = null;
    _tracksSubscription = null;
  }

  void consumeNewTrackBanner() {
    if (!_newTrackAdded) return;
    _newTrackAdded = false;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _friendlyError(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'unavailable') {
        return 'Network temporarily unavailable. Please retry in a moment.';
      }
      if (error.code == 'permission-denied') {
        return 'Permission denied. Please sign in again.';
      }
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!.trim();
      }
    }
    return error.toString();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _tracksSubscription?.cancel();
    super.dispose();
  }
}
