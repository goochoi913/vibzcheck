import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../firebase/firebase_auth_service.dart';
import '../firebase/firestore_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    FirebaseAuthService? authService,
    FirestoreService? firestoreService,
  }) : _authService = authService ?? FirebaseAuthService.instance,
       _firestoreService = firestoreService ?? FirestoreService.instance {
    _authSubscription = _authService.authStateChanges.listen(_handleAuthState);
  }

  final FirebaseAuthService _authService;
  final FirestoreService _firestoreService;
  late final StreamSubscription<User?> _authSubscription;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> _handleAuthState(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      notifyListeners();
      return;
    }

    try {
      final snapshot = await _firestoreService.userDoc(firebaseUser.uid).get();
      final data = snapshot.data();
      if (data != null) {
        _currentUser = UserModel.fromMap(data, uid: snapshot.id);
      }
    } catch (_) {
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<bool> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      return true;
    } catch (e) {
      _errorMessage = _parseAuthError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.signInWithEmail(email: email, password: password);
      return true;
    } catch (e) {
      _errorMessage = _parseAuthError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.signOut();
    } catch (e) {
      _errorMessage = _parseAuthError(e);
    } finally {
      _setLoading(false);
    }
  }

  String _parseAuthError(Object error) {
    final message = error.toString();
    if (message.contains('user-not-found')) return 'No account found for this email.';
    if (message.contains('wrong-password')) return 'Incorrect password.';
    if (message.contains('invalid-email')) return 'Please enter a valid email address.';
    if (message.contains('email-already-in-use')) return 'An account with this email already exists.';
    if (message.contains('weak-password')) return 'Password must be at least 6 characters.';
    return 'Authentication failed. Please try again.';
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
