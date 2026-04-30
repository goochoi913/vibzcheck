import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

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
}
