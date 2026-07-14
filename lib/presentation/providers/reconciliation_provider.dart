import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/cash_reconciliation_model.dart';
import '../../domain/repositories/sales_repository.dart';
import 'dart:developer' as dev;
import 'settings_provider.dart';

class ReconciliationState {
  final List<CashReconciliationModel> reconciliations;
  final String filterType; // 'today', 'weekly', 'monthly', 'custom'
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final bool isLoading;
  final String? errorMessage;

  ReconciliationState({
    this.reconciliations = const [],
    this.filterType = 'weekly',
    this.customStartDate,
    this.customEndDate,
    this.isLoading = false,
    this.errorMessage,
  });

  List<CashReconciliationModel> get filteredReconciliations {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (filterType == 'today') {
      start = DateTime(now.year, now.month, now.day);
    } else if (filterType == 'weekly') {
      start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    } else if (filterType == 'monthly') {
      start = DateTime(now.year, now.month, 1);
    } else {
      // custom
      if (customStartDate == null || customEndDate == null) return reconciliations;
      start = DateTime(customStartDate!.year, customStartDate!.month, customStartDate!.day);
      end = DateTime(customEndDate!.year, customEndDate!.month, customEndDate!.day, 23, 59, 59);
    }

    return reconciliations.where((rec) {
      return (rec.date.isAfter(start) || rec.date.isAtSameMomentAs(start)) &&
             (rec.date.isBefore(end) || rec.date.isAtSameMomentAs(end));
    }).toList();
  }

  // --- STATS COMPUTATIONS ---
  int get totalReconciliations => filteredReconciliations.length;

  int get totalDiscrepancyCount =>
      filteredReconciliations.where((rec) => rec.difference != 0).length;

  double get averageAccuracy {
    if (filteredReconciliations.isEmpty) return 100.0;
    final total = filteredReconciliations.fold(0.0, (sum, rec) => sum + rec.accuracyRate);
    return total / filteredReconciliations.length;
  }

  double get totalDifference {
    return filteredReconciliations.fold(0.0, (sum, rec) => sum + rec.difference);
  }

  ReconciliationState copyWith({
    List<CashReconciliationModel>? reconciliations,
    String? filterType,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool? isLoading,
    String? errorMessage,
    bool clearCustomDates = false,
  }) {
    return ReconciliationState(
      reconciliations: reconciliations ?? this.reconciliations,
      filterType: filterType ?? this.filterType,
      customStartDate: clearCustomDates ? null : (customStartDate ?? this.customStartDate),
      customEndDate: clearCustomDates ? null : (customEndDate ?? this.customEndDate),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ReconciliationNotifier extends StateNotifier<ReconciliationState> {
  final SalesRepository _salesRepository;

  ReconciliationNotifier(this._salesRepository) : super(ReconciliationState()) {
    fetchReconciliations();
  }

  Future<void> fetchReconciliations() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _salesRepository.getCashReconciliations();
      state = state.copyWith(reconciliations: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat analisis kas: $e',
      );
    }
  }

  void setFilterType(String type) {
    state = state.copyWith(filterType: type, clearCustomDates: type != 'custom');
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    state = state.copyWith(
      filterType: 'custom',
      customStartDate: start,
      customEndDate: end,
    );
  }
}

final reconciliationProvider =
    StateNotifierProvider<ReconciliationNotifier, ReconciliationState>((ref) {
  final repo = ref.watch(salesRepositoryProvider);
  return ReconciliationNotifier(repo);
});
