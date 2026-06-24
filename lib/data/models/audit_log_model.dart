import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogModel {
  final String id;
  final DateTime timestamp;
  final String userId;
  final String username;
  final String action;
  final String details;

  AuditLogModel({
    required this.id,
    required this.timestamp,
    required this.userId,
    required this.username,
    required this.action,
    required this.details,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.parse(val);
      return DateTime.now();
    }

    return AuditLogModel(
      id: json['id'] as String? ?? '',
      timestamp: parseDateTime(json['timestamp']),
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      action: json['action'] as String? ?? '',
      details: json['details'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': Timestamp.fromDate(timestamp),
      'user_id': userId,
      'username': username,
      'action': action,
      'details': details,
    };
  }
}
