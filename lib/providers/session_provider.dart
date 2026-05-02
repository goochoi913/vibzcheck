import 'dart:async';

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
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<SessionModel>? _sessionSubscription;
  StreamSubscription<List<TrackModel>>? _tracksSubscription;

  SessionModel? get currentSession => _currentSession;
  List<TrackModel> get tracks => _tracks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> createSession({
    required String sessionName,
    required String hostUID,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final session = await _firestoreService.createSession(
        sessionName: sessionName,
        hostUID: hostUID,
      );
      await _listenToSession(session.sessionId);
    } catch (error) {
      _errorMessage = error.toString();
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
    try {
      await _firestoreService.joinSession(
        sessionId: sessionId,
        userUID: userUID,
      );
      await _listenToSession(sessionId);
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> leaveSession() async {
    await _cancelSubscriptions();
    _currentSession = null;
    _tracks = const [];
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> voteOnTrack({
    required String trackId,
    required String voterUID,
  }) async {
    final sessionId = _currentSession?.sessionId;
    if (sessionId == null) return;

    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.voteOnTrack(
        sessionId: sessionId,
        trackId: trackId,
        voterUID: voterUID,
      );
    } on AlreadyVotedException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Unable to register vote. Please try again.';
      notifyListeners();
    }
  }

  Future<void> removeVote({
    required String trackId,
    required String voterUID,
  }) async {
    final sessionId = _currentSession?.sessionId;
    if (sessionId == null) return;

    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.removeVote(
        sessionId: sessionId,
        trackId: trackId,
        voterUID: voterUID,
      );
    } catch (error) {
      _errorMessage = 'Unable to remove vote. Please try again.';
      notifyListeners();
    }
  }

  Future<void> _listenToSession(String sessionId) async {
    await _cancelSubscriptions();

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
            _tracks = tracks;
            notifyListeners();
          },
          onError: (error) {
            _errorMessage = error.toString();
            notifyListeners();
          },
        );
  }

  Future<void> _cancelSubscriptions() async {
    await _sessionSubscription?.cancel();
    await _tracksSubscription?.cancel();
    _sessionSubscription = null;
    _tracksSubscription = null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _tracksSubscription?.cancel();
    super.dispose();
  }
}
