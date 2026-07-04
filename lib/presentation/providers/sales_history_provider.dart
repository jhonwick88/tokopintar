import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as dev;
import '../../data/models/sale_model.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/services/printer_service.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';

class SalesHistoryState {
  final List<SaleModel> sales;
  final DateTime? startDate;
  final DateTime? endDate;
  final String searchQuery;
  final String selectedPaymentMethod;
  final String selectedStatus;
  final bool isLoading;
  final String? errorMessage;

  SalesHistoryState({
    this.sales = const [],
    this.startDate,
    this.endDate,
    this.searchQuery = '',
    this.selectedPaymentMethod = 'all',
    this.selectedStatus = 'all',
    this.isLoading = false,
    this.errorMessage,
  });

  List<SaleModel> get filteredSales {
    return sales.where((s) {
      final matchesQuery = searchQuery.isEmpty || 
          s.invoiceNo.toLowerCase().contains(searchQuery.toLowerCase());
      
      final matchesPayment = selectedPaymentMethod == 'all' || 
          s.paymentMethod.toLowerCase() == selectedPaymentMethod.toLowerCase();
          
      final matchesStatus = selectedStatus == 'all' || 
          s.status.toLowerCase() == selectedStatus.toLowerCase();
          
      return matchesQuery && matchesPayment && matchesStatus;
    }).toList();
  }

  SalesHistoryState copyWith({
    List<SaleModel>? sales,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDates = false,
    String? searchQuery,
    String? selectedPaymentMethod,
    String? selectedStatus,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SalesHistoryState(
      sales: sales ?? this.sales,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      searchQuery: searchQuery ?? this.searchQuery,
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SalesHistoryNotifier extends StateNotifier<SalesHistoryState> {
  final SalesRepository _salesRepository;
  final Ref _ref;

  SalesHistoryNotifier(this._salesRepository, this._ref) : super(SalesHistoryState()) {
    fetchSales();
  }

  Future<void> fetchSales() async {
    state = state.copyWith(isLoading: true, errorMessage: null, clearError: true);
    try {
      final list = await _salesRepository.getSalesHistory(
        startDate: state.startDate,
        endDate: state.endDate,
      );
      state = state.copyWith(sales: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal mengambil riwayat transaksi: $e',
      );
    }
  }

  void updateDateFilter(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      state = state.copyWith(clearDates: true);
    } else {
      state = state.copyWith(startDate: start, endDate: end);
    }
    fetchSales();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setPaymentMethodFilter(String method) {
    state = state.copyWith(selectedPaymentMethod: method);
  }

  void setStatusFilter(String status) {
    state = state.copyWith(selectedStatus: status);
  }

  Future<bool> voidTransaction(String invoiceNo, String reason) async {
    final user = _ref.read(authNotifierProvider).currentUser;
    if (user == null) return false;

    try {
      // 1. Update status in Firestore
      await _salesRepository.updateSaleStatus(
        invoiceNo,
        'voided',
        reason: reason,
        user: user.fullname,
      );

      // 2. Audit log
      await _ref.read(auditRepositoryProvider).logActivity(
        user.uid,
        user.username,
        'void_transaction',
        'Voided transaction $invoiceNo. Reason: $reason',
      );

      // 3. Refresh list
      await fetchSales();
      return true;
    } catch (e) {
      dev.log('Void transaction failed: $e');
      return false;
    }
  }

  Future<bool> refundTransaction(String invoiceNo, String reason) async {
    final user = _ref.read(authNotifierProvider).currentUser;
    if (user == null) return false;

    try {
      // 1. Update status in Firestore
      await _salesRepository.updateSaleStatus(
        invoiceNo,
        'refunded',
        reason: reason,
        user: user.fullname,
      );

      // 2. Audit log
      await _ref.read(auditRepositoryProvider).logActivity(
        user.uid,
        user.username,
        'refund_transaction',
        'Refunded transaction $invoiceNo. Reason: $reason',
      );

      // 3. Refresh list
      await fetchSales();
      return true;
    } catch (e) {
      dev.log('Refund transaction failed: $e');
      return false;
    }
  }

  Future<bool> reprintReceipt(String invoiceNo) async {
    try {
      final sale = state.sales.firstWhere((s) => s.invoiceNo == invoiceNo);
      final settings = _ref.read(settingsNotifierProvider);
      final printBytes = PrinterService.instance.generateReceiptBytes(sale, settings);

      if (settings.printerType == 'LAN') {
        return await PrinterService.instance.printToLan(
          settings.printerIp,
          settings.printerPort,
          printBytes,
          copies: settings.printReceiptCopies,
        );
      } else if (settings.printerType == 'Bluetooth') {
        return await PrinterService.instance.printToBluetooth(
          settings.printerMacAddress,
          printBytes,
          copies: settings.printReceiptCopies,
        );
      } else {
        dev.log('Mock print: Invoice $invoiceNo reprinted.');
        return true;
      }
    } catch (e) {
      dev.log('Reprint receipt failed: $e');
      return false;
    }
  }

  Future<bool> reprintLastReceipt() async {
    if (state.sales.isEmpty) {
      await fetchSales();
    }
    if (state.sales.isNotEmpty) {
      final lastInvoice = state.sales.first.invoiceNo;
      return await reprintReceipt(lastInvoice);
    }
    return false;
  }
}

final salesHistoryNotifierProvider =
    StateNotifierProvider<SalesHistoryNotifier, SalesHistoryState>((ref) {
  final repo = ref.watch(salesRepositoryProvider);
  return SalesHistoryNotifier(repo, ref);
});
