class StockLedgerModel {
  final int id;
  final String itemNo;
  final String txType;
  final double qty;
  final String timestamp;
  final String notes;
  final String referenceId;

  StockLedgerModel({
    required this.id,
    required this.itemNo,
    required this.txType,
    required this.qty,
    required this.timestamp,
    required this.notes,
    required this.referenceId,
  });

  factory StockLedgerModel.fromJson(Map<String, dynamic> json) {
    return StockLedgerModel(
      id: json['id'] as int? ?? 0,
      itemNo: json['item_no'] as String? ?? '',
      txType: json['tx_type'] as String? ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      referenceId: json['reference_id'] as String? ?? '',
    );
  }
}
