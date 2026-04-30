import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  const MessageModel({
    required this.messageId,
    required this.senderUID,
    required this.senderName,
    required this.text,
    this.reaction,
    required this.sentAt,
  });

  final String messageId;
  final String senderUID;
  final String senderName;
  final String text;
  final String? reaction;
  final DateTime sentAt;

  factory MessageModel.fromMap(
    Map<String, dynamic> map, {
    required String messageId,
  }) {
    return MessageModel(
      messageId: messageId,
      senderUID: (map['senderUID'] as String?) ?? '',
      senderName: (map['senderName'] as String?) ?? '',
      text: (map['text'] as String?) ?? '',
      reaction: map['reaction'] as String?,
      sentAt: _parseDateTime(map['sentAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderUID': senderUID,
      'senderName': senderName,
      'text': text,
      'reaction': reaction,
      'sentAt': Timestamp.fromDate(sentAt),
    };
  }

  MessageModel copyWith({
    String? messageId,
    String? senderUID,
    String? senderName,
    String? text,
    String? reaction,
    bool clearReaction = false,
    DateTime? sentAt,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      senderUID: senderUID ?? this.senderUID,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      reaction: clearReaction ? null : (reaction ?? this.reaction),
      sentAt: sentAt ?? this.sentAt,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
