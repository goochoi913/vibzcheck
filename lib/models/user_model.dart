import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoURL,
    required this.favoriteGenres,
    required this.createdAt,
    required this.fcmToken,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoURL;
  final List<String> favoriteGenres;
  final DateTime createdAt;
  final String fcmToken;

  factory UserModel.fromMap(Map<String, dynamic> map, {required String uid}) {
    return UserModel(
      uid: uid,
      displayName: (map['displayName'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      photoURL: map['photoURL'] as String?,
      favoriteGenres: List<String>.from(
        map['favoriteGenres'] as List? ?? const [],
      ),
      createdAt: _parseDateTime(map['createdAt']),
      fcmToken: (map['fcmToken'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'favoriteGenres': favoriteGenres,
      'createdAt': Timestamp.fromDate(createdAt),
      'fcmToken': fcmToken,
    };
  }

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? photoURL,
    bool clearPhotoURL = false,
    List<String>? favoriteGenres,
    DateTime? createdAt,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: clearPhotoURL ? null : (photoURL ?? this.photoURL),
      favoriteGenres: favoriteGenres ?? this.favoriteGenres,
      createdAt: createdAt ?? this.createdAt,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
