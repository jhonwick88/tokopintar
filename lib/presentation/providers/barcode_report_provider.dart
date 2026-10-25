import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/barcode_log_model.dart';
import 'settings_provider.dart';
import 'dart:developer' as dev;

class BarcodeReportState {
  final BarcodeReportData data;
  final String datePreset; // 'today', 'last7days', 'last30days', 'custom'
  final DateTime? startDate;
  final DateTime? endDate;
  final String selectedUser; // 'all' or specific username
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  BarcodeReportState({
    required this.data,
    this.datePreset = 'today',
    this.startDate,
    this.endDate,
    this.selectedUser = 'all',
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  List<BarcodeLogModel> get filteredLogs {
    var list = data.logs;

    if (selectedUser != 'all' && selectedUser.isNotEmpty) {
      list = list
          .where((l) => l.username.toLowerCase() == selectedUser.toLowerCase())
          .toList();
    }

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((l) {
        return l.itemName.toLowerCase().contains(q) ||
            l.itemNo.toLowerCase().contains(q) ||
            l.barcode.toLowerCase().contains(q) ||
            l.username.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  BarcodeReportState copyWith({
    BarcodeReportData? data,
    String? datePreset,
    DateTime? startDate,
    DateTime? endDate,
    String? selectedUser,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BarcodeReportState(
      data: data ?? this.data,
      datePreset: datePreset ?? this.datePreset,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      selectedUser: selectedUser ?? this.selectedUser,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class BarcodeReportNotifier extends StateNotifier<BarcodeReportState> {
  final Ref _ref;

  BarcodeReportNotifier(this._ref)
      : super(
          BarcodeReportState(
            data: BarcodeReportData(),
            datePreset: 'today',
            startDate: DateTime(
                DateTime.now().year, DateTime.now().month, DateTime.now().day),
            endDate: DateTime(DateTime.now().year, DateTime.now().month,
                DateTime.now().day, 23, 59, 59),
          ),
        ) {
    loadReport();
  }

  Future<void> loadReport() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final client = _ref.read(apiClientProvider);
      final json = await client.getBarcodeLogs(
        startDate: state.startDate,
        endDate: state.endDate,
        username: state.selectedUser,
        search: state.searchQuery,
      );

      final reportData = BarcodeReportData.fromJson(json);
      state = state.copyWith(
        data: reportData,
        isLoading: false,
      );
    } catch (e) {
      dev.log('Failed to fetch barcode report: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat laporan rekam barcode: $e',
      );
    }
  }

  void applyDatePreset(String preset) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (preset) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'last7days':
        start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        break;
      case 'last30days':
        start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 29));
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
    }

    state = state.copyWith(
      datePreset: preset,
      startDate: start,
      endDate: end,
    );
    loadReport();
  }

  void setCustomRange(DateTime start, DateTime end) {
    final adjustedStart = DateTime(start.year, start.month, start.day, 0, 0, 0);
    final adjustedEnd =
        DateTime(end.year, end.month, end.day, 23, 59, 59, 999);

    state = state.copyWith(
      datePreset: 'custom',
      startDate: adjustedStart,
      endDate: adjustedEnd,
    );
    loadReport();
  }

  void setUserFilter(String user) {
    state = state.copyWith(selectedUser: user);
    loadReport();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final barcodeReportProvider =
    StateNotifierProvider<BarcodeReportNotifier, BarcodeReportState>((ref) {
  return BarcodeReportNotifier(ref);
});
