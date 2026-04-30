import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  const SessionModel({
    required this.sessionId,
    required this.hostUID,
    required this.sessionName,
    this.isActive = true,
    required this.collaborators,
    required this.createdAt,
  });

  final String sessionId;
  final String hostUID;
  final String sessionName;
  final bool isActive;
  final List<String> collaborators;
  final DateTime createdAt;

  factory SessionModel.fromMap(
    Map<String, dynamic> map, {
    required String sessionId,
  }) {
    return SessionModel(
      sessionId: sessionId,
      hostUID: (map['hostUID'] as String?) ?? '',
      sessionName: (map['sessionName'] as String?) ?? '',
      isActive: (map['isActive'] as bool?) ?? true,
      collaborators: List<String>.from(
        map['collaborators'] as List? ?? const [],
      ),
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostUID': hostUID,
      'sessionName': sessionName,
      'isActive': isActive,
      'collaborators': collaborators,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  SessionModel copyWith({
    String? sessionId,
    String? hostUID,
    String? sessionName,
    bool? isActive,
    List<String>? collaborators,
    DateTime? createdAt,
  }) {
    return SessionModel(
      sessionId: sessionId ?? this.sessionId,
      hostUID: hostUID ?? this.hostUID,
      sessionName: sessionName ?? this.sessionName,
      isActive: isActive ?? this.isActive,
      collaborators: collaborators ?? this.collaborators,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
