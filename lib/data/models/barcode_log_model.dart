class BarcodeLogModel {
  final String id;
  final String itemNo;
  final String itemName;
  final String barcode;
  final String previousBarcode;
  final String userId;
  final String username;
  final DateTime recordedAt;

  BarcodeLogModel({
    required this.id,
    required this.itemNo,
    required this.itemName,
    required this.barcode,
    required this.previousBarcode,
    required this.userId,
    required this.username,
    required this.recordedAt,
  });

  factory BarcodeLogModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is String) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return BarcodeLogModel(
      id: json['id'] as String? ?? '',
      itemNo: json['item_no'] as String? ?? '',
      itemName: json['item_name'] as String? ?? '',
      barcode: json['barcode'] as String? ?? '',
      previousBarcode: json['previous_barcode'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'Admin',
      recordedAt: parseDate(json['recorded_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_no': itemNo,
      'item_name': itemName,
      'barcode': barcode,
      'previous_barcode': previousBarcode,
      'user_id': userId,
      'username': username,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }
}

class StaffBarcodeStatModel {
  final String username;
  final int count;
  final double percentage;

  StaffBarcodeStatModel({
    required this.username,
    required this.count,
    required this.percentage,
  });

  factory StaffBarcodeStatModel.fromJson(Map<String, dynamic> json) {
    return StaffBarcodeStatModel(
      username: json['username'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BarcodeReportData {
  final List<BarcodeLogModel> logs;
  final int totalPeriod;
  final String topRecorder;
  final List<StaffBarcodeStatModel> staffStats;
  final int totalStoreItems;
  final int storeWithBarcode;
  final double storeProgressPct;

  BarcodeReportData({
    this.logs = const [],
    this.totalPeriod = 0,
    this.topRecorder = '-',
    this.staffStats = const [],
    this.totalStoreItems = 0,
    this.storeWithBarcode = 0,
    this.storeProgressPct = 0.0,
  });

  factory BarcodeReportData.fromJson(Map<String, dynamic> json) {
    final rawLogs = json['logs'] as List? ?? [];
    final logsList = rawLogs
        .map((e) => BarcodeLogModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawStats = json['staff_stats'] as List? ?? [];
    final statsList = rawStats
        .map((e) => StaffBarcodeStatModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return BarcodeReportData(
      logs: logsList,
      totalPeriod: (json['total_period'] as num?)?.toInt() ?? 0,
      topRecorder: json['top_recorder'] as String? ?? '-',
      staffStats: statsList,
      totalStoreItems: (json['total_store_items'] as num?)?.toInt() ?? 0,
      storeWithBarcode: (json['store_with_barcode'] as num?)?.toInt() ?? 0,
      storeProgressPct: (json['store_progress_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
