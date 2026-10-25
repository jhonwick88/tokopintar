import 'package:flutter_test/flutter_test.dart';
import 'package:tokopintar/data/models/sale_model.dart';
import 'package:tokopintar/presentation/providers/sales_history_provider.dart';

void main() {
  group('SalesHistoryState Date & Omset Filtering Tests', () {
    final sale1 = SaleModel(
      invoiceNo: 'INV001',
      date: DateTime(2026, 9, 29, 9, 10, 0),
      cashier: 'Kasir 1',
      subtotal: 50000,
      discount: 0,
      grandTotal: 50000,
      paymentMethod: 'cash',
      paidAmount: 50000,
      changeAmount: 0,
      status: 'completed',
    );

    final sale2 = SaleModel(
      invoiceNo: 'INV002',
      date: DateTime(2026, 9, 29, 20, 26, 54, 327),
      cashier: 'Kasir 2',
      subtotal: 75000,
      discount: 5000,
      grandTotal: 70000,
      paymentMethod: 'qris',
      paidAmount: 70000,
      changeAmount: 0,
      status: 'completed',
    );

    final saleVoided = SaleModel(
      invoiceNo: 'INV003',
      date: DateTime(2026, 9, 29, 14, 0, 0),
      cashier: 'Kasir 1',
      subtotal: 30000,
      discount: 0,
      grandTotal: 30000,
      paymentMethod: 'cash',
      paidAmount: 30000,
      changeAmount: 0,
      status: 'voided',
    );

    final saleAugust = SaleModel(
      invoiceNo: 'INV004',
      date: DateTime(2026, 8, 22, 12, 0, 0),
      cashier: 'Kasir 1',
      subtotal: 100000,
      discount: 0,
      grandTotal: 100000,
      paymentMethod: 'bank',
      paidAmount: 100000,
      changeAmount: 0,
      status: 'completed',
    );

    final allSales = [sale1, sale2, saleVoided, saleAugust];

    test('Filters sales correctly by single day range (2026-09-29)', () {
      final state = SalesHistoryState(
        sales: allSales,
        startDate: DateTime(2026, 9, 29, 0, 0, 0, 0),
        endDate: DateTime(2026, 9, 29, 23, 59, 59, 999),
      );

      final filtered = state.filteredSales;
      expect(filtered.length, 3);
      expect(filtered.map((s) => s.invoiceNo).toSet(), {'INV001', 'INV002', 'INV003'});

      // Active omset excludes voided
      final omset = filtered
          .where((s) => s.status != 'voided' && s.status != 'refunded')
          .fold<double>(0.0, (sum, s) => sum + s.grandTotal);
      expect(omset, 120000.0); // 50000 + 70000
    });

    test('Filters sales correctly for August only', () {
      final state = SalesHistoryState(
        sales: allSales,
        startDate: DateTime(2026, 8, 1, 0, 0, 0),
        endDate: DateTime(2026, 8, 31, 23, 59, 59, 999),
      );

      final filtered = state.filteredSales;
      expect(filtered.length, 1);
      expect(filtered.first.invoiceNo, 'INV004');

      final omset = filtered
          .where((s) => s.status != 'voided' && s.status != 'refunded')
          .fold<double>(0.0, (sum, s) => sum + s.grandTotal);
      expect(omset, 100000.0);
    });

    test('All sales shown when startDate and endDate are null', () {
      final state = SalesHistoryState(
        sales: allSales,
        startDate: null,
        endDate: null,
      );

      final filtered = state.filteredSales;
      expect(filtered.length, 4);

      final omset = filtered
          .where((s) => s.status != 'voided' && s.status != 'refunded')
          .fold<double>(0.0, (sum, s) => sum + s.grandTotal);
      expect(omset, 220000.0); // 50000 + 70000 + 100000
    });
  });
}
