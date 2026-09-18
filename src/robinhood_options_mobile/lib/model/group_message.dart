import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  system,
}

class GroupMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final Map<String, DateTime> readBy;

  GroupMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.text,
    required this.timestamp,
    this.type = MessageType.text,
    this.readBy = const {},
  });

  factory GroupMessage.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GroupMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      senderPhotoUrl: data['senderPhotoUrl'],
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${data['type']}',
        orElse: () => MessageType.text,
      ),
      readBy: (data['readBy'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              (value as Timestamp).toDate(),
            ),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type.toString().split('.').last,
      'readBy': readBy.map((key, value) => MapEntry(
            key,
            Timestamp.fromDate(value),
          )),
    };
  }
}
