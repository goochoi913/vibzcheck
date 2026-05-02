import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/message_model.dart';
import '../models/session_model.dart';
import '../models/track_model.dart';
import '../models/user_model.dart';

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

  DocumentReference<Map<String, dynamic>> userDoc(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  CollectionReference<Map<String, dynamic>> sessionsRef() {
    return _firestore.collection('sessions');
  }

  CollectionReference<Map<String, dynamic>> tracksRef(String sessionId) {
    return sessionsRef().doc(sessionId).collection('tracks');
  }

  CollectionReference<Map<String, dynamic>> messagesRef(String sessionId) {
    return sessionsRef().doc(sessionId).collection('messages');
  }

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

  Future<void> joinSession({
    required String sessionId,
    required String userUID,
  }) async {
    final ref = sessionsRef().doc(sessionId);
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
  }

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

  Future<void> addTrack({
    required String sessionId,
    required TrackModel track,
  }) async {
    final ref = tracksRef(sessionId).doc();
    final trackToSave = track.copyWith(trackId: ref.id);
    await ref.set(trackToSave.toMap());
  }

  Stream<List<TrackModel>> getTracksStream(String sessionId) {
    return tracksRef(sessionId)
        .orderBy('voteCount', descending: true)
        .orderBy('addedAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TrackModel.fromMap(doc.data(), trackId: doc.id))
              .toList(),
        );
  }

  Future<void> deleteTrack({
    required String sessionId,
    required String trackId,
  }) {
    return tracksRef(sessionId).doc(trackId).delete();
  }

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

  Future<UserModel?> getUser(String uid) async {
    final snapshot = await userDoc(uid).get();
    final data = snapshot.data();
    if (data == null) return null;
    return UserModel.fromMap(data, uid: snapshot.id);
  }

  Future<void> updateUser(UserModel user) {
    return userDoc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  Future<void> updateTrackMoodTags({
    required String sessionId,
    required String trackId,
    required List<String> moodTags,
  }) {
    return tracksRef(
      sessionId,
    ).doc(trackId).set({'moodTags': moodTags}, SetOptions(merge: true));
  }

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

  Stream<List<MessageModel>> getMessagesStream(String sessionId) {
    return messagesRef(sessionId)
        .orderBy('sentAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => MessageModel.fromMap(doc.data(), messageId: doc.id),
              )
              .toList(),
        );
  }

  Future<void> addReaction({
    required String sessionId,
    required String messageId,
    required String reaction,
  }) {
    return messagesRef(sessionId).doc(messageId).set(
      {'reaction': reaction},
      SetOptions(merge: true),
    );
  }
}
