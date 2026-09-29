import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/cash_reconciliation_model.dart';
import '../../data/models/cash_movement_model.dart';
import '../../domain/repositories/sales_repository.dart';
import 'dart:developer' as dev;
import 'settings_provider.dart';

class ReconciliationState {
  final List<CashReconciliationModel> reconciliations;
  final List<CashMovementModel> cashMovements;
  final String filterType; // 'today', 'weekly', 'monthly', 'custom'
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final bool isLoading;
  final String? errorMessage;

  ReconciliationState({
    this.reconciliations = const [],
    this.cashMovements = const [],
    this.filterType = 'weekly',
    this.customStartDate,
    this.customEndDate,
    this.isLoading = false,
    this.errorMessage,
  });

  DateTimeRange get _activeRange {
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
      if (customStartDate == null || customEndDate == null) {
        start = DateTime(2000);
      } else {
        start = DateTime(customStartDate!.year, customStartDate!.month, customStartDate!.day);
        end = DateTime(customEndDate!.year, customEndDate!.month, customEndDate!.day, 23, 59, 59);
      }
    }
    return DateTimeRange(start: start, end: end);
  }

  List<CashReconciliationModel> get filteredReconciliations {
    final range = _activeRange;
    return reconciliations.where((rec) {
      final d = rec.date.toLocal();
      return (d.isAfter(range.start) || d.isAtSameMomentAs(range.start)) &&
             (d.isBefore(range.end) || d.isAtSameMomentAs(range.end));
    }).toList();
  }

  List<CashMovementModel> get filteredCashMovements {
    final range = _activeRange;
    return cashMovements.where((mov) {
      final d = mov.date.toLocal();
      return (d.isAfter(range.start) || d.isAtSameMomentAs(range.start)) &&
             (d.isBefore(range.end) || d.isAtSameMomentAs(range.end));
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

  double get totalCashOut {
    return filteredCashMovements
        .where((m) => m.type == 'OUT')
        .fold(0.0, (sum, m) => sum + m.amount);
  }

  double get todayCashOut {
    final now = DateTime.now();
    return cashMovements
        .where((m) {
          final d = m.date.toLocal();
          return m.type == 'OUT' &&
              d.year == now.year &&
              d.month == now.month &&
              d.day == now.day;
        })
        .fold(0.0, (sum, m) => sum + m.amount);
  }

  ReconciliationState copyWith({
    List<CashReconciliationModel>? reconciliations,
    List<CashMovementModel>? cashMovements,
    String? filterType,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool? isLoading,
    String? errorMessage,
    bool clearCustomDates = false,
  }) {
    return ReconciliationState(
      reconciliations: reconciliations ?? this.reconciliations,
      cashMovements: cashMovements ?? this.cashMovements,
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
    fetchData();
  }

  Future<void> fetchData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final reconciliations = await _salesRepository.getCashReconciliations();
      final movements = await _salesRepository.getCashMovements();
      state = state.copyWith(
        reconciliations: reconciliations,
        cashMovements: movements,
        isLoading: false,
      );
    } catch (e) {
      dev.log('Failed to fetch cash data: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat analisis kas: $e',
      );
    }
  }

  Future<void> fetchReconciliations() async {
    await fetchData();
  }

  Future<void> addCashMovement(CashMovementModel movement) async {
    try {
      final created = await _salesRepository.saveCashMovement(movement);
      state = state.copyWith(
        cashMovements: [created, ...state.cashMovements],
      );
    } catch (e) {
      dev.log('Failed to add cash movement: $e');
      rethrow;
    }
  }

  Future<void> deleteCashMovement(String id) async {
    try {
      await _salesRepository.deleteCashMovement(id);
      state = state.copyWith(
        cashMovements: state.cashMovements.where((m) => m.id != id).toList(),
      );
    } catch (e) {
      dev.log('Failed to delete cash movement: $e');
      rethrow;
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
