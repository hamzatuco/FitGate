import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationItem {
  final String id;
  final String message;
  final DateTime? timestamp;
  final String? type;

  NotificationItem({
    required this.id,
    required this.message,
    this.timestamp,
    this.type,
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationItem(
      id: doc.id,
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      type: data['type'],
    );
  }
}
