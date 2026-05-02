import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/message_model.dart';
import '../models/session_model.dart';
import '../models/track_model.dart';
import '../models/user_model.dart';
import '../models/user_stats.dart';

class AlreadyVotedException implements Exception {
  const AlreadyVotedException([
    this.message = 'You already voted on this track.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class FirestoreService {
  FirestoreService._({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _firestore;

  /// Returns a reference to the `users/{uid}` profile document.
  DocumentReference<Map<String, dynamic>> userDoc(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  /// Returns the top-level `sessions` collection reference.
  CollectionReference<Map<String, dynamic>> sessionsRef() {
    return _firestore.collection('sessions');
  }

  /// Returns the `sessions/{sessionId}/tracks` sub-collection reference.
  CollectionReference<Map<String, dynamic>> tracksRef(String sessionId) {
    return sessionsRef().doc(sessionId).collection('tracks');
  }

  /// Returns the `sessions/{sessionId}/messages` sub-collection reference.
  CollectionReference<Map<String, dynamic>> messagesRef(String sessionId) {
    return sessionsRef().doc(sessionId).collection('messages');
  }

  /// Creates a new session document with generated ID and host ownership metadata.
  Future<SessionModel> createSession({
    required String sessionName,
    required String hostUID,
  }) async {
    final now = DateTime.now();
    final docRef = sessionsRef().doc();
    final session = SessionModel(
      sessionId: docRef.id,
      hostUID: hostUID,
      sessionName: sessionName,
      isActive: true,
      collaborators: const [],
      createdAt: now,
    );

    await docRef.set(session.toMap());
    return session;
  }

  /// Adds a collaborator UID atomically using `arrayUnion` to prevent duplicates.
  ///
  /// Retries transient Firestore failures (`unavailable`, `aborted`) before surfacing an error.
  Future<void> joinSession({
    required String sessionId,
    required String userUID,
  }) async {
    final ref = sessionsRef().doc(sessionId);
    var attempt = 0;

    while (true) {
      try {
        await _firestore.runTransaction((transaction) async {
          final snapshot = await transaction.get(ref);
          if (!snapshot.exists) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              message: 'Session not found.',
            );
          }
          transaction.update(ref, {
            'collaborators': FieldValue.arrayUnion([userUID]),
          });
        });
        return;
      } on FirebaseException catch (error) {
        final isRetryable =
            error.code == 'unavailable' || error.code == 'aborted';
        if (!isRetryable || attempt >= 2) rethrow;
        attempt += 1;
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }
  }

  /// Streams a single session document in real time from `sessions/{sessionId}`.
  Stream<SessionModel> getSession(String sessionId) {
    return sessionsRef().doc(sessionId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          message: 'Session not found.',
        );
      }
      return SessionModel.fromMap(data, sessionId: snapshot.id);
    });
  }

  /// Streams active sessions ordered by newest first for lobby discovery.
  Stream<List<SessionModel>> getActiveSessions() {
    return sessionsRef()
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SessionModel.fromMap(doc.data(), sessionId: doc.id))
              .toList(),
        );
  }

  /// Writes a new track document into `sessions/{sessionId}/tracks` with generated document ID.
  Future<void> addTrack({
    required String sessionId,
    required TrackModel track,
  }) async {
    final ref = tracksRef(sessionId).doc();
    final trackToSave = track.copyWith(trackId: ref.id);
    await ref.set(trackToSave.toMap());
  }

  /// Streams queue tracks ordered by vote priority then insertion time.
  ///
  /// Supports pagination with `limit` and `startAfterTrack` cursor.
  Stream<List<TrackModel>> getTracksStream(
    String sessionId, {
    int limit = 50,
    TrackModel? startAfterTrack,
  }) {
    Query<Map<String, dynamic>> query = tracksRef(
      sessionId,
    ).orderBy('voteCount', descending: true).orderBy('addedAt').limit(limit);

    if (startAfterTrack != null) {
      query = query.startAfter([
        startAfterTrack.voteCount,
        Timestamp.fromDate(startAfterTrack.addedAt),
      ]);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => TrackModel.fromMap(doc.data(), trackId: doc.id))
          .toList(),
    );
  }

  /// Deletes one track document from `sessions/{sessionId}/tracks/{trackId}`.
  Future<void> deleteTrack({
    required String sessionId,
    required String trackId,
  }) {
    return tracksRef(sessionId).doc(trackId).delete();
  }

  /// Registers a vote atomically and increments `voteCount` in the same transaction.
  ///
  /// Uses a per-user vote document guard to block duplicate votes.
  Future<void> voteOnTrack({
    required String sessionId,
    required String trackId,
    required String voterUID,
  }) async {
    final trackRef = tracksRef(sessionId).doc(trackId);
    final voteRef = trackRef.collection('votes').doc(voterUID);

    await _firestore.runTransaction((transaction) async {
      final trackSnapshot = await transaction.get(trackRef);
      if (!trackSnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          message: 'Track not found.',
        );
      }

      final voteSnapshot = await transaction.get(voteRef);
      if (voteSnapshot.exists) {
        throw const AlreadyVotedException();
      }

      transaction.set(voteRef, {
        'voterUID': voterUID,
        'votedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(trackRef, {'voteCount': FieldValue.increment(1)});
    });
  }

  /// Removes a user's vote atomically and decrements `voteCount` if vote exists.
  Future<void> removeVote({
    required String sessionId,
    required String trackId,
    required String voterUID,
  }) async {
    final trackRef = tracksRef(sessionId).doc(trackId);
    final voteRef = trackRef.collection('votes').doc(voterUID);

    await _firestore.runTransaction((transaction) async {
      final trackSnapshot = await transaction.get(trackRef);
      if (!trackSnapshot.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          message: 'Track not found.',
        );
      }

      final voteSnapshot = await transaction.get(voteRef);
      if (!voteSnapshot.exists) {
        return;
      }

      transaction.delete(voteRef);
      transaction.update(trackRef, {'voteCount': FieldValue.increment(-1)});
    });
  }

  /// Checks whether `voterUID` already has a vote doc under a track's `votes` sub-collection.
  Future<bool> hasUserVotedOnTrack({
    required String sessionId,
    required String trackId,
    required String voterUID,
  }) async {
    final voteSnapshot = await tracksRef(
      sessionId,
    ).doc(trackId).collection('votes').doc(voterUID).get();
    return voteSnapshot.exists;
  }

  /// Reads one user profile document and maps it to [UserModel].
  Future<UserModel?> getUser(String uid) async {
    final snapshot = await userDoc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return UserModel.fromMap(data, uid: snapshot.id);
  }

  /// Upserts user profile fields into `users/{uid}` with merge semantics.
  Future<void> updateUser(UserModel user) {
    return userDoc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  /// Updates only `moodTags` for a track document using merge to avoid overwriting other fields.
  Future<void> updateTrackMoodTags({
    required String sessionId,
    required String trackId,
    required List<String> moodTags,
  }) {
    return tracksRef(
      sessionId,
    ).doc(trackId).set({'moodTags': moodTags}, SetOptions(merge: true));
  }

  /// Aggregates user stats across sessions, tracks, and votes for profile insights.
  Future<UserStats> getUserStats(String userUID) async {
    final sessionsJoined = await _safeCount(
      sessionsRef().where('collaborators', arrayContains: userUID),
    );

    final tracksAdded = await _safeCount(
      _firestore
          .collectionGroup('tracks')
          .where('addedByUID', isEqualTo: userUID),
    );

    final votesCast = await _safeCount(
      _firestore.collectionGroup('votes').where('voterUID', isEqualTo: userUID),
    );

    return UserStats(
      sessionsJoined: sessionsJoined,
      tracksAdded: tracksAdded,
      votesCast: votesCast,
    );
  }

  /// Counts documents via aggregate query with fallback to snapshot length for compatibility.
  Future<int> _safeCount(Query<Map<String, dynamic>> query) async {
    try {
      final aggregate = await query.count().get();
      return aggregate.count ?? 0;
    } catch (_) {
      final snapshot = await query.get();
      return snapshot.docs.length;
    }
  }

  /// Creates a new chat message under `sessions/{sessionId}/messages` with generated message ID.
  Future<void> sendMessage({
    required String sessionId,
    required String senderUID,
    required String senderName,
    required String text,
  }) async {
    final messageRef = messagesRef(sessionId).doc();
    final message = MessageModel(
      messageId: messageRef.id,
      senderUID: senderUID,
      senderName: senderName,
      text: text.trim(),
      reaction: null,
      sentAt: DateTime.now(),
    );

    await messageRef.set(message.toMap());
  }

  /// Streams chat messages from `sessions/{sessionId}/messages` oldest-to-newest.
  Stream<List<MessageModel>> getMessagesStream(String sessionId) {
    return messagesRef(sessionId)
        .orderBy('sentAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data(), messageId: doc.id))
              .toList(),
        );
  }

  /// Writes/replaces a single emoji reaction field on a message document using merge semantics.
  Future<void> addReaction({
    required String sessionId,
    required String messageId,
    required String reaction,
  }) {
    return messagesRef(
      sessionId,
    ).doc(messageId).set({'reaction': reaction}, SetOptions(merge: true));
  }
}
