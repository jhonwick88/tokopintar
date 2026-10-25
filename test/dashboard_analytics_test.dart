import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:tokopintar/data/models/sale_model.dart';

void main() {
  group('Dashboard Analytics Filtering and Calculations Tests', () {
    final now = DateTime(2026, 10, 25, 14, 30, 0);

    final saleToday = SaleModel(
      invoiceNo: 'INV-TODAY',
      date: DateTime(2026, 10, 25, 10, 15, 0),
      cashier: 'Kasir 1',
      subtotal: 50000,
      discount: 0,
      grandTotal: 50000,
      paymentMethod: 'CASH',
      paidAmount: 50000,
      changeAmount: 0,
      status: 'completed',
    );

    final saleYesterday = SaleModel(
      invoiceNo: 'INV-YESTERDAY',
      date: DateTime(2026, 10, 24, 16, 45, 0),
      cashier: 'Kasir 2',
      subtotal: 100000,
      discount: 10000,
      grandTotal: 90000,
      paymentMethod: 'qris',
      paidAmount: 90000,
      changeAmount: 0,
      status: 'completed',
    );

    final saleEarlierThisMonth = SaleModel(
      invoiceNo: 'INV-EARLIER-MONTH',
      date: DateTime(2026, 10, 5, 11, 0, 0),
      cashier: 'Kasir 1',
      subtotal: 75000,
      discount: 0,
      grandTotal: 75000,
      paymentMethod: 'BANK',
      paidAmount: 75000,
      changeAmount: 0,
      status: 'completed',
    );

    final saleLastMonth = SaleModel(
      invoiceNo: 'INV-LAST-MONTH',
      date: DateTime(2026, 9, 28, 9, 30, 0),
      cashier: 'Kasir 1',
      subtotal: 120000,
      discount: 0,
      grandTotal: 120000,
      paymentMethod: 'transfer',
      paidAmount: 120000,
      changeAmount: 0,
      status: 'completed',
    );

    final saleVoided = SaleModel(
      invoiceNo: 'INV-VOIDED',
      date: DateTime(2026, 10, 25, 12, 0, 0),
      cashier: 'Kasir 1',
      subtotal: 40000,
      discount: 0,
      grandTotal: 40000,
      paymentMethod: 'cash',
      paidAmount: 40000,
      changeAmount: 0,
      status: 'voided',
    );

    final saleRefunded = SaleModel(
      invoiceNo: 'INV-REFUNDED',
      date: DateTime(2026, 10, 25, 13, 0, 0),
      cashier: 'Kasir 1',
      subtotal: 30000,
      discount: 0,
      grandTotal: 30000,
      paymentMethod: 'cash',
      paidAmount: 30000,
      changeAmount: 0,
      status: 'refunded',
    );

    final allSales = [
      saleToday,
      saleYesterday,
      saleEarlierThisMonth,
      saleLastMonth,
      saleVoided,
      saleRefunded,
    ];

    List<SaleModel> filterCompleted(List<SaleModel> sales, DateTime? start, DateTime? end) {
      return sales.where((s) {
        final statusLower = s.status.toLowerCase().trim();
        if (statusLower == 'voided' || statusLower == 'refunded' || statusLower == 'cancelled') {
          return false;
        }
        final saleDate = s.date.toLocal();
        if (start != null && saleDate.isBefore(start)) return false;
        if (end != null && saleDate.isAfter(end)) return false;
        return true;
      }).toList();
    }

    test('Filters today sales excluding voided and refunded', () {
      final startToday = DateTime(now.year, now.month, now.day, 0, 0, 0, 0);
      final endToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      final result = filterCompleted(allSales, startToday, endToday);
      expect(result.length, 1);
      expect(result.first.invoiceNo, 'INV-TODAY');
      expect(result.first.grandTotal, 50000);
    });

    test('Filters yesterday sales correctly', () {
      final y = now.subtract(const Duration(days: 1));
      final startY = DateTime(y.year, y.month, y.day, 0, 0, 0, 0);
      final endY = DateTime(y.year, y.month, y.day, 23, 59, 59, 999);

      final result = filterCompleted(allSales, startY, endY);
      expect(result.length, 1);
      expect(result.first.invoiceNo, 'INV-YESTERDAY');
      expect(result.first.grandTotal, 90000);
    });

    test('Filters this month sales correctly (Oct 1 to Oct 25)', () {
      final startMonth = DateTime(now.year, now.month, 1, 0, 0, 0, 0);
      final endMonth = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

      final result = filterCompleted(allSales, startMonth, endMonth);
      expect(result.length, 3); // today, yesterday, earlier this month
      final totalRevenue = result.fold(0.0, (acc, s) => acc + s.grandTotal);
      expect(totalRevenue, 50000 + 90000 + 75000);
    });

    test('Payment method grouping handles case insensitivity and card/transfer types', () {
      double cashTotal = 0;
      double qrisTotal = 0;
      double bankTotal = 0;

      for (var sale in [saleToday, saleYesterday, saleEarlierThisMonth, saleLastMonth]) {
        final pm = sale.paymentMethod.toLowerCase().trim();
        if (pm == 'cash' || pm == 'tunai') {
          cashTotal += sale.grandTotal;
        } else if (pm == 'qris') {
          qrisTotal += sale.grandTotal;
        } else if (pm.contains('bank') || pm.contains('transfer') || pm.contains('card') || pm.contains('edc') || pm.contains('debit') || pm.contains('credit')) {
          bankTotal += sale.grandTotal;
        } else {
          cashTotal += sale.grandTotal;
        }
      }

      expect(cashTotal, 50000); // saleToday (CASH)
      expect(qrisTotal, 90000); // saleYesterday (qris)
      expect(bankTotal, 75000 + 120000); // saleEarlierThisMonth (BANK) + saleLastMonth (transfer)
    });

    test('Chart bucketing for daily range creates exact calendar day buckets', () {
      final start = DateTime(2026, 10, 20);
      final end = DateTime(2026, 10, 25);
      final Map<String, double> chartData = {};

      DateTime current = start;
      while (!current.isAfter(end)) {
        final key = DateFormat('dd/MM').format(current);
        chartData[key] = 0.0;
        current = current.add(const Duration(days: 1));
      }

      expect(chartData.containsKey('20/10'), isTrue);
      expect(chartData.containsKey('24/10'), isTrue);
      expect(chartData.containsKey('25/10'), isTrue);
      expect(chartData.length, 6); // 20, 21, 22, 23, 24, 25

      // Add sales to buckets
      for (var s in [saleToday, saleYesterday]) {
        final key = DateFormat('dd/MM').format(s.date.toLocal());
        if (chartData.containsKey(key)) {
          chartData[key] = chartData[key]! + s.grandTotal;
        }
      }

      expect(chartData['25/10'], 50000);
      expect(chartData['24/10'], 90000);
      expect(chartData['20/10'], 0);
    });
  });
}
