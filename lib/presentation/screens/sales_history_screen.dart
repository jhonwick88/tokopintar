import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/sale_model.dart';
import '../providers/sales_history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reconciliation_provider.dart';
import '../widgets/main_layout.dart';
import '../widgets/cash_out_dialog.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _PosReceiptPreview extends ConsumerWidget {
  final SaleModel sale;

  const _PosReceiptPreview({required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: 'Courier', color: Colors.black, fontSize: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Text('STRUK BELANJA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(settings.shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(settings.shopAddress),
                  Text('Telp: ${settings.shopPhone}'),
                  if (settings.receiptHeader.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(settings.receiptHeader, textAlign: TextAlign.center),
                  ],
                  const Text('===================================='),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Invoice : ${sale.invoiceNo}'),
            Text('Tanggal : ${DateFormat('dd/MM/yyyy HH:mm').format(sale.date)}'),
            Text('Kasir   : ${sale.cashier}'),
            if (sale.status != 'completed') ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                color: sale.status == 'voided' ? Colors.red.shade100 : Colors.orange.shade100,
                child: Text(
                  'STATUS  : ${sale.status.toUpperCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: sale.status == 'voided' ? Colors.red.shade800 : Colors.orange.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const Text('------------------------------------'),
            const SizedBox(height: 8),
            
            // Items List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sale.items.length,
              itemBuilder: (context, index) {
                final item = sale.items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('  ${item.qty} x ${currencyFormatter.format(item.price)} ${item.note.isNotEmpty ? '| ${item.note}' : ''}'),
                          Text(currencyFormatter.format(item.subtotal)),
                         
                        ],
                      ),
                      
                    ],
                  ),
                );
              },
            ),
            
            const Text('------------------------------------'),
            _buildReceiptRow('Subtotal:', currencyFormatter.format(sale.subtotal)),
            if (sale.discount > 0)
              _buildReceiptRow('Diskon:', '-${currencyFormatter.format(sale.discount)}'),
            if (sale.serviceCharge > 0)
              _buildReceiptRow('Service Charge:', currencyFormatter.format(sale.serviceCharge)),
            if (sale.tax > 0)
              _buildReceiptRow('Pajak (PPN):', currencyFormatter.format(sale.tax)),
            const SizedBox(height: 4),
            _buildReceiptRow('TOTAL:', currencyFormatter.format(sale.grandTotal), bold: true),
            const Text('------------------------------------'),
            _buildReceiptRow('Bayar (${sale.paymentMethod.toUpperCase()}):', currencyFormatter.format(sale.paidAmount)),
            _buildReceiptRow('Kembalian:', currencyFormatter.format(sale.changeAmount)),
            const Text('===================================='),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: Column(
                children: [
                  if (settings.receiptFooter.isNotEmpty) ...[
                    Text(settings.receiptFooter, textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                  ],
                  const Text('Terima Kasih'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String val, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(val, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  SaleModel? _selectedSale;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();

  String _selectedDateRangePreset = 'today';
  DateTimeRange? _customDateRange;
  int _currentPage = 1;
  int _itemsPerPage = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyDatePreset('today');
      ref.read(reconciliationProvider.notifier).fetchData();
    });
  }

  void _applyDatePreset(String preset) {
    setState(() {
      _selectedDateRangePreset = preset;
      _currentPage = 1;
    });

    final now = DateTime.now();
    DateTime? start;
    DateTime? end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (preset) {
      case 'all':
        start = null;
        end = null;
        break;
      case 'today':
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        break;
      case 'yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0);
        end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59, 999);
        break;
      case 'last7days':
        final d7 = now.subtract(const Duration(days: 6));
        start = DateTime(d7.year, d7.month, d7.day, 0, 0, 0);
        break;
      case 'last30days':
        final d30 = now.subtract(const Duration(days: 29));
        start = DateTime(d30.year, d30.month, d30.day, 0, 0, 0);
        break;
      case 'thismonth':
        start = DateTime(now.year, now.month, 1, 0, 0, 0);
        break;
      case 'custom':
        if (_customDateRange != null) {
          start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day, 0, 0, 0);
          end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59, 999);
        } else {
          start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        }
        break;
      default:
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
    }

    ref.read(salesHistoryNotifierProvider.notifier).updateDateFilter(start, end);
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
            end: now,
          ),
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
      });
      _applyDatePreset('custom');
    }
  }

  void _refreshToday() {
    _applyDatePreset('today');
    ref.read(reconciliationProvider.notifier).fetchData();
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _isReprinting = false;
  DateTime? _lastF8PressTime;

  void _handleRawKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.f8) {
      if (_isReprinting) return;
      final now = DateTime.now();
      if (_lastF8PressTime != null && now.difference(_lastF8PressTime!).inMilliseconds < 1500) {
        return;
      }
      _lastF8PressTime = now;
      if (_selectedSale != null) {
        _reprint(_selectedSale!.invoiceNo);
      } else {
        _reprintLastReceipt();
      }
    }
  }

  void _reprintLastReceipt() async {
    if (_isReprinting) return;
    _isReprinting = true;
    try {
      final success = await ref.read(salesHistoryNotifierProvider.notifier).reprintLastReceipt();
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cetak ulang nota terakhir berhasil dikirim'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal cetak ulang. Riwayat transaksi kosong!'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      _isReprinting = false;
    }
  }

  void _showActionDialog(String type, String title, Function(String) onSubmit) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              hintText: 'Masukkan alasan...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: type == 'void' ? Colors.red : Colors.orange,
              ),
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isNotEmpty) {
                  onSubmit(reason);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Konfirmasi', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _processVoid(String invoiceNo, String reason) async {
    final success = await ref
        .read(salesHistoryNotifierProvider.notifier)
        .voidTransaction(invoiceNo, reason);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi berhasil di-VOID'), backgroundColor: Colors.red),
      );
      setState(() {
        _selectedSale = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal melakukan VOID'), backgroundColor: Colors.orange),
      );
    }
  }

  void _processRefund(String invoiceNo, String reason) async {
    final success = await ref
        .read(salesHistoryNotifierProvider.notifier)
        .refundTransaction(invoiceNo, reason);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaksi berhasil di-REFUND'), backgroundColor: Colors.orange),
      );
      setState(() {
        _selectedSale = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal melakukan REFUND'), backgroundColor: Colors.red),
      );
    }
  }

  void _reprint(String invoiceNo) async {
    final success = await ref
        .read(salesHistoryNotifierProvider.notifier)
        .reprintReceipt(invoiceNo);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Print job berhasil dikirim'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim print job'), backgroundColor: Colors.red),
      );
    }
  }

  void _showReceiptPreviewModal(BuildContext context, SaleModel sale) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Preview History', style: TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: _PosReceiptPreview(sale: sale),
            ),
          ),
          actionsPadding: const EdgeInsets.all(16),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sale.status == 'completed') ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showActionDialog(
                              'refund',
                              'Refund Transaksi',
                              (reason) => _processRefund(sale.invoiceNo, reason),
                            );
                          },
                          icon: const Icon(Icons.assignment_return, color: Colors.orange),
                          label: const Text('Refund', style: TextStyle(color: Colors.orange)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showActionDialog(
                              'void',
                              'Void Transaksi',
                              (reason) => _processVoid(sale.invoiceNo, reason),
                            );
                          },
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text('Void', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('Tutup'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          _reprint(sale.invoiceNo);
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('Cetak Ulang'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(salesHistoryNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final isAdmin = authState.currentUser?.role.toLowerCase() == 'admin';
    final width = MediaQuery.of(context).size.width;
    final isLarge = width >= 900;
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    final activeRevenue = historyState.filteredSales
        .where((s) => s.status != 'voided' && s.status != 'refunded')
        .fold(0.0, (sum, s) => sum + s.grandTotal);
    final voidedCount = historyState.filteredSales
        .where((s) => s.status == 'voided' || s.status == 'refunded')
        .length;
    final totalDiscounts = historyState.filteredSales
        .fold(0.0, (sum, s) => sum + s.discount);
    
    final today = DateTime.now();
    final todaySales = historyState.sales
        .where((s) => s.date.year == today.year && s.date.month == today.month && s.date.day == today.day)
        .where((s) => s.status != 'voided' && s.status != 'refunded')
        .toList();
    final todayRevenue = todaySales.fold(0.0, (sum, s) => sum + s.grandTotal);
    final todayCashRevenue = todaySales
        .where((s) => s.paymentMethod.toLowerCase() == 'cash')
        .fold(0.0, (sum, s) => sum + s.grandTotal);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleRawKeyEvent,
      child: MainLayout(
        currentRoute: '/history',
        child: Scaffold(
        appBar: AppBar(
          title: const Text('Riwayat', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Muat Ulang / Hari Ini',
              onPressed: _refreshToday,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Ekspor ke CSV',
              onPressed: () => _exportToCSV(historyState.filteredSales),
            ),
            IconButton(
              icon: const Icon(Icons.point_of_sale),
              tooltip: 'Rekonsiliasi Kas Laci (Hari Ini)',
              onPressed: () => _showCashReconciliationDialog(todayRevenue, todayCashRevenue),
            ),
            if (isAdmin) ...[
              IconButton(
                icon: const Icon(Icons.date_range),
                tooltip: 'Pilih Rentang Tanggal',
                onPressed: _pickCustomDateRange,
              ),
              if (historyState.startDate != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _selectedDateRangePreset = 'all';
                      _customDateRange = null;
                      _currentPage = 1;
                    });
                    ref.read(salesHistoryNotifierProvider.notifier).updateDateFilter(null, null);
                  },
                  tooltip: 'Reset Filter Tanggal (Tampilkan Semua)',
                ),
            ],
          ],
        ),
        body: Row(
          children: [
            // Left Column: Invoices List
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      ref.read(salesHistoryNotifierProvider.notifier).fetchSales(),
                      ref.read(reconciliationProvider.notifier).fetchData(),
                    ]);
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                    // Summary Cards Grid
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: isLarge
                            ? Row(
                                children: [
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: 'Transaksi',
                                      value: '${historyState.filteredSales.length}',
                                      icon: Icons.receipt_long,
                                      color: Colors.blue,
                                      subtitle: isAdmin ? _getDateFilterLabel() : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: 'Total Omset',
                                      value: currencyFormatter.format(activeRevenue),
                                      icon: Icons.monetization_on,
                                      color: Colors.green,
                                      subtitle: isAdmin ? _getDateFilterLabel() : 'Kas Laci',
                                      onTap: () => _showCashReconciliationDialog(todayRevenue, todayCashRevenue),
                                      tooltip: 'Klik untuk Rekonsiliasi Kas Laci',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: 'Void / Refund',
                                      value: '$voidedCount',
                                      icon: Icons.cancel,
                                      color: Colors.red,
                                      subtitle: isAdmin ? _getDateFilterLabel() : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: 'Total Diskon',
                                      value: currencyFormatter.format(totalDiscounts),
                                      icon: Icons.percent,
                                      color: Colors.purple,
                                      subtitle: isAdmin ? _getDateFilterLabel() : null,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildMetricCard(
                                          title: 'Transaksi',
                                          value: '${historyState.filteredSales.length}',
                                          icon: Icons.receipt_long,
                                          color: Colors.blue,
                                          subtitle: isAdmin ? _getDateFilterLabel() : null,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildMetricCard(
                                          title: 'Total Omset',
                                          value: currencyFormatter.format(activeRevenue),
                                          icon: Icons.monetization_on,
                                          color: Colors.green,
                                          subtitle: isAdmin ? _getDateFilterLabel() : 'Kas Laci',
                                          onTap: () => _showCashReconciliationDialog(todayRevenue, todayCashRevenue),
                                          tooltip: 'Klik untuk Rekonsiliasi Kas Laci',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildMetricCard(
                                          title: 'Void / Refund',
                                          value: '$voidedCount',
                                          icon: Icons.cancel,
                                          color: Colors.red,
                                          subtitle: isAdmin ? _getDateFilterLabel() : null,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildMetricCard(
                                          title: 'Total Diskon',
                                          value: currencyFormatter.format(totalDiscounts),
                                          icon: Icons.percent,
                                          color: Colors.purple,
                                          subtitle: isAdmin ? _getDateFilterLabel() : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),
                    
                    // Pinned Header: Search Bar & Filters
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SearchAndFilterHeaderDelegate(
                        height: isLarge
                            ? (isAdmin ? 175.0 : 125.0)
                            : (isAdmin ? 225.0 : 175.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date Presets Row (Only visible for admin)
                            if (isAdmin) ...[
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildDateChip('Hari Ini', 'today'),
                                    _buildDateChip('Kemarin', 'yesterday'),
                                    _buildDateChip('7 Hari', 'last7days'),
                                    _buildDateChip('1 Bulan', 'last30days'),
                                    _buildDateChip('Bulan Ini', 'thismonth'),
                                    _buildDateChip('Semua', 'all'),
                                    _buildDateChip(
                                      _selectedDateRangePreset == 'custom' && _customDateRange != null
                                          ? '${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM').format(_customDateRange!.end)}'
                                          : 'Pilih Rentang...',
                                      'custom',
                                      icon: Icons.calendar_today_rounded,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            // Search Bar
                            TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                isDense: true,
                                prefixIcon: Icon(Icons.search, size: 20),
                                hintText: 'Cari No. Invoice / Nama Produk / Kasir...',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _currentPage = 1;
                                });
                                ref.read(salesHistoryNotifierProvider.notifier).setSearchQuery(val.trim());
                              },
                            ),
                            const SizedBox(height: 8),
                            // Filters dropdowns
                            if (isLarge) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: historyState.selectedPaymentMethod,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        labelText: 'Metode Bayar',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'all', child: Text('Semua Metode', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'cash', child: Text('Tunai', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'qris', child: Text('QRIS', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'bank', child: Text('Bank/Card', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'ewallet', child: Text('E-Wallet', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _currentPage = 1;
                                          });
                                          ref.read(salesHistoryNotifierProvider.notifier).setPaymentMethodFilter(val);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: historyState.selectedStatus,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        labelText: 'Status',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'all', child: Text('Semua Status', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'completed', child: Text('Completed', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'voided', child: Text('Voided', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'refunded', child: Text('Refunded', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _currentPage = 1;
                                          });
                                          ref.read(salesHistoryNotifierProvider.notifier).setStatusFilter(val);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: historyState.selectedPaymentMethod,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        labelText: 'Metode Bayar',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'all', child: Text('Semua', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'cash', child: Text('Tunai', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'qris', child: Text('QRIS', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'bank', child: Text('Bank', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'ewallet', child: Text('E-Wallet', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _currentPage = 1;
                                          });
                                          ref.read(salesHistoryNotifierProvider.notifier).setPaymentMethodFilter(val);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: historyState.selectedStatus,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        labelText: 'Status',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'all', child: Text('Semua', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'completed', child: Text('Completed', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'voided', child: Text('Voided', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                        DropdownMenuItem(value: 'refunded', child: Text('Refunded', overflow: TextOverflow.ellipsis, maxLines: 1)),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _currentPage = 1;
                                          });
                                          ref.read(salesHistoryNotifierProvider.notifier).setStatusFilter(val);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    // Invoices List Content with Pagination
                    if (historyState.isLoading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (historyState.filteredSales.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('Tidak ada riwayat transaksi')),
                      )
                    else ...[
                      Builder(
                        builder: (context) {
                          final allItems = historyState.filteredSales;
                          final totalItems = allItems.length;
                          final totalPages = (totalItems / _itemsPerPage).ceil().clamp(1, 999999);
                          final safeCurrentPage = _currentPage.clamp(1, totalPages);
                          final startIndex = (safeCurrentPage - 1) * _itemsPerPage;
                          final paginatedSales = allItems.skip(startIndex).take(_itemsPerPage).toList();

                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final sale = paginatedSales[index];
                                final isSelected = _selectedSale?.invoiceNo == sale.invoiceNo;
                                
                                Color statusColor = Colors.green;
                                if (sale.status == 'voided') {
                                  statusColor = Colors.red;
                                } else if (sale.status == 'refunded') {
                                  statusColor = Colors.orange;
                                }

                                return Column(
                                  children: [
                                    ListTile(
                                      selected: isSelected,
                                      selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                      title: Text(
                                        sale.invoiceNo,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      subtitle: Text(
                                        '${DateFormat('dd/MM/yyyy HH:mm').format(sale.date)} | ${sale.cashier}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            currencyFormatter.format(sale.grandTotal),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              sale.status.toUpperCase(),
                                              style: TextStyle(color: statusColor, fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _selectedSale = sale;
                                        });
                                        if (!isLarge) {
                                          _showReceiptPreviewModal(context, sale);
                                        }
                                      },
                                    ),
                                    if (index < paginatedSales.length - 1)
                                      const Divider(height: 1),
                                  ],
                                );
                              },
                              childCount: paginatedSales.length,
                            ),
                          );
                        },
                      ),
                      Builder(
                        builder: (context) {
                          final totalItems = historyState.filteredSales.length;
                          final totalPages = (totalItems / _itemsPerPage).ceil().clamp(1, 999999);
                          final safeCurrentPage = _currentPage.clamp(1, totalPages);
                          final startIndex = (safeCurrentPage - 1) * _itemsPerPage;

                          return SliverToBoxAdapter(
                            child: _buildPaginationBar(
                              currentPage: safeCurrentPage,
                              totalPages: totalPages,
                              totalItems: totalItems,
                              itemsPerPage: _itemsPerPage,
                              startIndex: startIndex,
                              onPageChanged: (p) => setState(() => _currentPage = p),
                              onItemsPerPageChanged: (n) => setState(() {
                                _itemsPerPage = n;
                                _currentPage = 1;
                              }),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
                ),
              ),
            ),
            
            const VerticalDivider(width: 1),
            
            // Right Column: Invoice Detail Preview (visible on large screen)
            if (isLarge)
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _selectedSale == null
                      ? const Center(child: Text('Pilih salah satu struk untuk melihat detail'))
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PosReceiptPreview(sale: _selectedSale!),
                              const SizedBox(height: 20),
                              
                              // Detail Action Buttons
                              if (_selectedSale!.status == 'completed') ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _showActionDialog(
                                          'refund',
                                          'Refund Transaksi',
                                          (reason) => _processRefund(_selectedSale!.invoiceNo, reason),
                                        ),
                                        icon: const Icon(Icons.assignment_return, color: Colors.orange),
                                        label: const Text('Refund', style: TextStyle(color: Colors.orange)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _showActionDialog(
                                          'void',
                                          'Void Transaksi',
                                          (reason) => _processVoid(_selectedSale!.invoiceNo, reason),
                                        ),
                                        icon: const Icon(Icons.cancel, color: Colors.red),
                                        label: const Text('Void', style: TextStyle(color: Colors.red)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                              
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _reprint(_selectedSale!.invoiceNo),
                                icon: const Icon(Icons.print),
                                label: const Text('Cetak Nota Thermal'),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

  String _getDateFilterLabel() {
    switch (_selectedDateRangePreset) {
      case 'today':
        return 'Hari Ini';
      case 'yesterday':
        return 'Kemarin';
      case 'last7days':
        return '7 Hari Terakhir';
      case 'last30days':
        return '1 Bulan Terakhir';
      case 'thismonth':
        return 'Bulan Ini';
      case 'all':
        return 'Semua Transaksi';
      case 'custom':
        if (_customDateRange != null) {
          return '${DateFormat('dd/MM/yy').format(_customDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_customDateRange!.end)}';
        }
        return 'Rentang Khusus';
      default:
        return 'Hari Ini';
    }
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    String? subtitle,
    String? tooltip,
  }) {
    final cardContent = Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 14, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 10, color: color.withOpacity(0.8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      subtitle,
                      style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap != null) {
      return Tooltip(
        message: tooltip ?? 'Filter Tanggal',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.0),
          child: cardContent,
        ),
      );
    }
    return cardContent;
  }

  void _showCashReconciliationDialog(double todayRevenue, double todayCashRevenue) {
    // Fetch latest cash movements data immediately upon opening dialog
    ref.read(reconciliationProvider.notifier).fetchData();

    final authState = ref.read(authNotifierProvider);
    final defaultOperator = authState.currentUser?.fullname.isNotEmpty == true
        ? authState.currentUser!.fullname
        : (authState.currentUser?.username ?? '');
    final operatorController = TextEditingController(text: defaultOperator);
    final cashController = TextEditingController();
    final notesController = TextEditingController();
    double actualCash = 0.0;
    String? operatorError;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final recState = ref.watch(reconciliationProvider);
            final todayCashOut = recState.todayCashOut;
            final expectedSystemCash = (todayCashRevenue - todayCashOut).clamp(0.0, double.infinity);
            final difference = actualCash - expectedSystemCash;
            
            double accuracyRate;
            if (expectedSystemCash == 0) {
              accuracyRate = actualCash == 0 ? 100.0 : 0.0;
            } else {
              if (actualCash >= expectedSystemCash) {
                accuracyRate = (expectedSystemCash / actualCash) * 100;
              } else {
                accuracyRate = (actualCash / expectedSystemCash) * 100;
              }
            }
            
            Color accuracyColor = Colors.red;
            if (accuracyRate >= 98.0) {
              accuracyColor = Colors.green;
            } else if (accuracyRate >= 90.0) {
              accuracyColor = Colors.orange;
            }

            final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.balance, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('Rekonsiliasi Kas Laci'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bandingkan uang fisik di laci dengan kas bersih sistem hari ini.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    // Summary Breakdown Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Penjualan Tunai:', style: TextStyle(fontSize: 13)),
                              Text(
                                currencyFormatter.format(todayCashRevenue),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text('Kas Keluar (Laci):', style: TextStyle(fontSize: 13, color: Colors.orange)),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () async {
                                      final res = await CashOutDialog.show(context);
                                      if (res == true) {
                                        await ref.read(reconciliationProvider.notifier).fetchData();
                                        setState(() {});
                                      }
                                    },
                                    child: const Icon(Icons.add_circle_outline, size: 16, color: Colors.orange),
                                  ),
                                ],
                              ),
                              Text(
                                '- ${currencyFormatter.format(todayCashOut)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Kas Bersih Seharusnya:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(
                                currencyFormatter.format(expectedSystemCash),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: operatorController,
                      decoration: InputDecoration(
                        labelText: 'Nama Inputer',
                        prefixIcon: const Icon(Icons.person),
                        hintText: 'Masukkan nama Anda',
                        errorText: operatorError,
                      ),
                      onChanged: (val) {
                        if (operatorError != null && val.trim().isNotEmpty) {
                          setState(() {
                            operatorError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: cashController,
                      decoration: const InputDecoration(
                        labelText: 'Uang Fisik di Laci (Rp)',
                        prefixIcon: Icon(Icons.payments),
                        hintText: 'Masukkan jumlah uang fisik di laci',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        setState(() {
                          actualCash = double.tryParse(val) ?? 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Selisih:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(
                          difference == 0
                              ? 'Cocok'
                              : (difference > 0 ? '+' : '') + currencyFormatter.format(difference),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: difference == 0
                                ? Colors.green
                                : (difference > 0 ? Colors.orange : Colors.red),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tingkat Akurasi:', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(
                          '${accuracyRate.toStringAsFixed(1)}%',
                          style: TextStyle(fontWeight: FontWeight.bold, color: accuracyColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: accuracyRate / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(accuracyColor),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Catatan (Opsional)',
                        hintText: 'Contoh: Selisih Rp 2.000 karena pembulatan...',
                        prefixIcon: Icon(Icons.note_alt),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final opName = operatorController.text.trim();
                    if (opName.isEmpty) {
                      setState(() {
                        operatorError = 'Nama inputer wajib diisi';
                      });
                      return;
                    }
                    
                    Navigator.of(context).pop();
                    
                    final success = await ref
                        .read(salesHistoryNotifierProvider.notifier)
                        .saveReconciliation(
                          systemRevenue: expectedSystemCash,
                          actualDrawerCash: actualCash,
                          notes: notesController.text.trim(),
                          operatorName: opName,
                        );
                    
                    if (success) {
                      ref.read(reconciliationProvider.notifier).fetchReconciliations();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rekonsiliasi kas berhasil disimpan'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gagal menyimpan rekonsiliasi kas'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Simpan Rekonsiliasi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportToCSV(List<SaleModel> sales) async {
    try {
      final csvBuffer = StringBuffer();
      // CSV Headers
      csvBuffer.writeln('Invoice No,Tanggal,Kasir,Subtotal,Diskon,Pajak,Layanan,Total,Metode Pembayaran,Status');
      
      for (var sale in sales) {
        final dateStr = sale.date.toIso8601String();
        csvBuffer.writeln(
          '${sale.invoiceNo},'
          '$dateStr,'
          '"${sale.cashier}",'
          '${sale.subtotal},'
          '${sale.discount},'
          '${sale.tax},'
          '${sale.serviceCharge},'
          '${sale.grandTotal},'
          '${sale.paymentMethod},'
          '${sale.status}'
        );
      }
      
      final downloadsDir = Directory('C:\\Users\\labsPintar\\Downloads');
      late File file;
      if (downloadsDir.existsSync()) {
        file = File('${downloadsDir.path}\\laporan_penjualan_${DateTime.now().millisecondsSinceEpoch}.csv');
      } else {
        file = File('laporan_penjualan_${DateTime.now().millisecondsSinceEpoch}.csv');
      }
      
      await file.writeAsString(csvBuffer.toString());
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Laporan berhasil diekspor ke: ${file.path}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengekspor laporan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDateChip(String label, String preset, {IconData? icon}) {
    final isSelected = _selectedDateRangePreset == preset;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        avatar: icon != null
            ? Icon(icon, size: 14, color: isSelected ? Colors.white : theme.colorScheme.primary)
            : null,
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.grey.shade800,
        ),
        selected: isSelected,
        selectedColor: theme.colorScheme.primary,
        backgroundColor: theme.cardColor,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        onSelected: (_) {
          if (preset == 'custom') {
            _pickCustomDateRange();
          } else {
            _applyDatePreset(preset);
          }
        },
      ),
    );
  }

  Widget _buildPaginationBar({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required int itemsPerPage,
    required int startIndex,
    required ValueChanged<int> onPageChanged,
    required ValueChanged<int> onItemsPerPageChanged,
  }) {
    final theme = Theme.of(context);
    final endItem = (startIndex + itemsPerPage).clamp(1, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15))),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Data ${startIndex + 1} - $endItem dari $totalItems',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: itemsPerPage,
                isDense: true,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10 / hal', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 20, child: Text('20 / hal', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 50, child: Text('50 / hal', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 100, child: Text('100 / hal', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) {
                  if (val != null) onItemsPerPageChanged(val);
                },
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page, size: 18),
                tooltip: 'Halaman Pertama',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage > 1 ? () => onPageChanged(1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: 'Sebelumnya',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$currentPage / $totalPages',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: 'Berikutnya',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 18),
                tooltip: 'Halaman Terakhir',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: currentPage < totalPages ? () => onPageChanged(totalPages) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _SearchAndFilterHeaderDelegate({
    required this.child,
    required this.height,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 3.0 : 0.0,
      shadowColor: Colors.black.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SearchAndFilterHeaderDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}

