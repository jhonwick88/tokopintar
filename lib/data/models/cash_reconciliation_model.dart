import 'package:cloud_firestore/cloud_firestore.dart';

class CashReconciliationModel {
  final String id;
  final DateTime date;
  final String cashierName;
  final double systemRevenue;
  final double actualDrawerCash;
  final double difference;
  final double accuracyRate;
  final String notes;

  CashReconciliationModel({
    required this.id,
    required this.date,
    required this.cashierName,
    required this.systemRevenue,
    required this.actualDrawerCash,
    required this.difference,
    required this.accuracyRate,
    this.notes = '',
  });

  factory CashReconciliationModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.parse(val);
      return DateTime.now();
    }

    return CashReconciliationModel(
      id: json['id'] as String? ?? '',
      date: parseDateTime(json['date']),
      cashierName: json['cashier_name'] as String? ?? '',
      systemRevenue: (json['system_revenue'] as num?)?.toDouble() ?? 0.0,
      actualDrawerCash: (json['actual_drawer_cash'] as num?)?.toDouble() ?? 0.0,
      difference: (json['difference'] as num?)?.toDouble() ?? 0.0,
      accuracyRate: (json['accuracy_rate'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'cashier_name': cashierName,
      'system_revenue': systemRevenue,
      'actual_drawer_cash': actualDrawerCash,
      'difference': difference,
      'accuracy_rate': accuracyRate,
      'notes': notes,
    };
  }
}
