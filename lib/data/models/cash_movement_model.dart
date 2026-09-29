class CashMovementModel {
  final String id;
  final DateTime date;
  final String cashierName;
  final String type; // 'OUT' or 'IN'
  final String category; // 'Pengamen', 'Sumbangan', 'Operasional', 'Konsumsi', 'Lain-lain'
  final double amount;
  final String notes;

  CashMovementModel({
    required this.id,
    required this.date,
    required this.cashierName,
    this.type = 'OUT',
    required this.category,
    required this.amount,
    this.notes = '',
  });

  factory CashMovementModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed.toLocal();
      }
      return DateTime.now();
    }

    return CashMovementModel(
      id: json['id'] as String? ?? '',
      date: parseDateTime(json['date']),
      cashierName: json['cashier_name'] as String? ?? '',
      type: json['type'] as String? ?? 'OUT',
      category: json['category'] as String? ?? 'Operasional',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'cashier_name': cashierName,
      'type': type,
      'category': category,
      'amount': amount,
      'notes': notes,
    };
  }

  CashMovementModel copyWith({
    String? id,
    DateTime? date,
    String? cashierName,
    String? type,
    String? category,
    double? amount,
    String? notes,
  }) {
    return CashMovementModel(
      id: id ?? this.id,
      date: date ?? this.date,
      cashierName: cashierName ?? this.cashierName,
      type: type ?? this.type,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
    );
  }
}
