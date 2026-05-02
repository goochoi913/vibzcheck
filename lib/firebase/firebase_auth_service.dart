import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/user_model.dart';
import 'firestore_service.dart';

class FirebaseAuthService {
  FirebaseAuthService._({
    FirebaseAuth? auth,
    FirebaseMessaging? messaging,
    FirestoreService? firestoreService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _firestoreService = firestoreService ?? FirestoreService.instance;

  static final FirebaseAuthService instance = FirebaseAuthService._();

  final FirebaseAuth _auth;
  final FirebaseMessaging _messaging;
  final FirestoreService _firestoreService;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid != null) {
      await _syncFcmTokenBestEffort(uid: uid);
    }

    return credential;
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await credential.user?.updateDisplayName(displayName);

    final uid = credential.user?.uid;
    var token = '';
    if (uid != null) {
      token = await _getFcmTokenBestEffort();
      final newUser = UserModel(
        uid: uid,
        displayName: displayName,
        email: email,
        photoURL: credential.user?.photoURL,
        favoriteGenres: const [],
        createdAt: DateTime.now(),
        fcmToken: token,
      );
      await _firestoreService.userDoc(uid).set(newUser.toMap());
    }

    return credential;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> _syncFcmTokenBestEffort({required String uid}) async {
    final token = await _getFcmTokenBestEffort();
    if (token.isEmpty) return;
    await _firestoreService.userDoc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  Future<String> _getFcmTokenBestEffort() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      return await _messaging.getToken() ?? '';
    } on FirebaseException {
      // App Check / network hiccups should not block sign-in.
      return '';
    } catch (_) {
      return '';
    }
  }
}
