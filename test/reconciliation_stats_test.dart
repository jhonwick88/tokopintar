import 'package:flutter_test/flutter_test.dart';
import 'package:tokopintar/data/models/cash_reconciliation_model.dart';
import 'package:tokopintar/data/models/cash_movement_model.dart';
import 'package:tokopintar/presentation/providers/reconciliation_provider.dart';

void main() {
  group('ReconciliationState Latest Hour Per Day Calculation Tests', () {
    test('Calculates stats taking only the latest reconciliation on the same day', () {
      final recShiftPagi = CashReconciliationModel(
        id: 'rec_1',
        date: DateTime(2026, 10, 25, 13, 0), // 13:00
        cashierName: 'Kasir Pagi',
        systemRevenue: 500000,
        actualDrawerCash: 500000,
        difference: 0,
        accuracyRate: 100,
      );

      final recShiftSiang = CashReconciliationModel(
        id: 'rec_2',
        date: DateTime(2026, 10, 25, 21, 0), // 21:00 (Latest closing of the day)
        cashierName: 'Kasir Siang',
        systemRevenue: 1200000,
        actualDrawerCash: 1195000,
        difference: -5000,
        accuracyRate: 99.58,
      );

      final movShiftPagi = CashMovementModel(
        id: 'mov_1',
        date: DateTime(2026, 10, 25, 12, 0),
        cashierName: 'Kasir Pagi',
        type: 'OUT',
        category: 'Pengamen',
        amount: 20000,
      );

      final movShiftSiang = CashMovementModel(
        id: 'mov_2',
        date: DateTime(2026, 10, 25, 20, 30), // Latest cash out
        cashierName: 'Kasir Siang',
        type: 'OUT',
        category: 'Operasional',
        amount: 50000,
      );

      final state = ReconciliationState(
        reconciliations: [recShiftPagi, recShiftSiang],
        cashMovements: [movShiftPagi, movShiftSiang],
        filterType: 'all',
      );

      // Latest record per day check
      expect(state.latestReconciliationsPerDay.length, 1);
      expect(state.isLatestReconciliation(recShiftSiang), isTrue);
      expect(state.isLatestReconciliation(recShiftPagi), isFalse);

      // Metrics must reflect the 21:00 closing, NOT 500k + 1.2M = 1.7M
      expect(state.totalSystemRevenue, 1200000);
      expect(state.totalActualDrawerCash, 1195000);
      expect(state.totalDifference, -5000);
      expect(state.totalCashOut, 50000);
      expect(state.totalDiscrepancyCount, 1);
    });

    test('Sums latest records across multiple different days correctly', () {
      final day1Shift1 = CashReconciliationModel(
        id: 'd1_s1',
        date: DateTime(2026, 10, 24, 13, 0),
        cashierName: 'A',
        systemRevenue: 400000,
        actualDrawerCash: 400000,
        difference: 0,
        accuracyRate: 100,
      );
      final day1Shift2 = CashReconciliationModel(
        id: 'd1_s2',
        date: DateTime(2026, 10, 24, 21, 0),
        cashierName: 'B',
        systemRevenue: 1000000,
        actualDrawerCash: 1000000,
        difference: 0,
        accuracyRate: 100,
      );

      final day2Shift1 = CashReconciliationModel(
        id: 'd2_s1',
        date: DateTime(2026, 10, 25, 13, 0),
        cashierName: 'A',
        systemRevenue: 600000,
        actualDrawerCash: 600000,
        difference: 0,
        accuracyRate: 100,
      );
      final day2Shift2 = CashReconciliationModel(
        id: 'd2_s2',
        date: DateTime(2026, 10, 25, 21, 0),
        cashierName: 'B',
        systemRevenue: 1500000,
        actualDrawerCash: 1480000,
        difference: -20000,
        accuracyRate: 98.67,
      );

      final state = ReconciliationState(
        reconciliations: [day1Shift1, day1Shift2, day2Shift1, day2Shift2],
        filterType: 'all',
      );

      expect(state.latestReconciliationsPerDay.length, 2);
      // Day 1 (1M) + Day 2 (1.5M) = 2.5M
      expect(state.totalSystemRevenue, 2500000);
      // Day 1 (1M) + Day 2 (1.48M) = 2.48M
      expect(state.totalActualDrawerCash, 2480000);
      // Day 1 (0) + Day 2 (-20k) = -20k
      expect(state.totalDifference, -20000);
      expect(state.totalDiscrepancyCount, 1);
    });
  });
}
