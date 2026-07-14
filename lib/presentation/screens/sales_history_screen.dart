import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/sale_model.dart';
import '../providers/sales_history_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/main_layout.dart';

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
                          Text('  ${item.qty} x ${currencyFormatter.format(item.price)}'),
                          Text(currencyFormatter.format(item.subtotal)),
                        ],
                      ),
                      if (item.note.isNotEmpty)
                        Text('  * Note: ${item.note}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
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

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleRawKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.f8) {
      if (_selectedSale != null) {
        _reprint(_selectedSale!.invoiceNo);
      } else {
        _reprintLastReceipt();
      }
    }
  }

  void _reprintLastReceipt() async {
    final success = await ref.read(salesHistoryNotifierProvider.notifier).reprintLastReceipt();
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
    final todayRevenue = historyState.sales
        .where((s) => s.date.year == today.year && s.date.month == today.month && s.date.day == today.day)
        .where((s) => s.status != 'voided' && s.status != 'refunded')
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
              icon: const Icon(Icons.download),
              tooltip: 'Ekspor ke CSV',
              onPressed: () => _exportToCSV(historyState.filteredSales),
            ),
            IconButton(
              icon: const Icon(Icons.date_range),
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2025),
                  lastDate: DateTime(2030),
                  initialDateRange: historyState.startDate != null && historyState.endDate != null
                      ? DateTimeRange(start: historyState.startDate!, end: historyState.endDate!)
                      : null,
                );
                if (picked != null) {
                  ref
                      .read(salesHistoryNotifierProvider.notifier)
                      .updateDateFilter(picked.start, picked.end);
                }
              },
            ),
            if (historyState.startDate != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  ref.read(salesHistoryNotifierProvider.notifier).updateDateFilter(null, null);
                },
                tooltip: 'Reset Filter Tanggal',
              ),
          ],
        ),
        body: Row(
          children: [
            // Left Column: Invoices List
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: CustomScrollView(
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
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: 'Omzet',
                                      value: currencyFormatter.format(activeRevenue),
                                      icon: Icons.monetization_on,
                                      color: Colors.green,
                                      onTap: () => _showCashReconciliationDialog(todayRevenue),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: 'Void/Refund',
                                      value: '$voidedCount',
                                      icon: Icons.cancel,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildMetricCard(
                                      title: 'Diskon',
                                      value: currencyFormatter.format(totalDiscounts),
                                      icon: Icons.percent,
                                      color: Colors.purple,
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
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildMetricCard(
                                          title: 'Omzet',
                                          value: currencyFormatter.format(activeRevenue),
                                          icon: Icons.monetization_on,
                                          color: Colors.green,
                                          onTap: () => _showCashReconciliationDialog(todayRevenue),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildMetricCard(
                                          title: 'Void/Refund',
                                          value: '$voidedCount',
                                          icon: Icons.cancel,
                                          color: Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildMetricCard(
                                          title: 'Diskon',
                                          value: currencyFormatter.format(totalDiscounts),
                                          icon: Icons.percent,
                                          color: Colors.purple,
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
                        height: isLarge ? 140.0 : 210.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Search Bar
                            TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'Cari No. Invoice... (F8 cetak ulang)',
                              ),
                              onChanged: (val) {
                                ref.read(salesHistoryNotifierProvider.notifier).setSearchQuery(val.trim());
                              },
                            ),
                            const SizedBox(height: 12),
                            // Filters dropdowns
                            if (isLarge) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: historyState.selectedPaymentMethod,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
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
                                          ref.read(salesHistoryNotifierProvider.notifier).setStatusFilter(val);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              DropdownButtonFormField<String>(
                                value: historyState.selectedPaymentMethod,
                                isExpanded: true,
                                decoration: const InputDecoration(
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
                                    ref.read(salesHistoryNotifierProvider.notifier).setPaymentMethodFilter(val);
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: historyState.selectedStatus,
                                isExpanded: true,
                                decoration: const InputDecoration(
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
                                    ref.read(salesHistoryNotifierProvider.notifier).setStatusFilter(val);
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    // Invoices List Content
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
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final sale = historyState.filteredSales[index];
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
                                if (index < historyState.filteredSales.length - 1)
                                  const Divider(height: 1),
                              ],
                            );
                          },
                          childCount: historyState.filteredSales.length,
                        ),
                      ),
                  ],
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
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
                Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
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
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.0),
        child: cardContent,
      );
    }
    return cardContent;
  }

  void _showCashReconciliationDialog(double todayRevenue) {
    final cashController = TextEditingController();
    final notesController = TextEditingController();
    double actualCash = 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final difference = actualCash - todayRevenue;
            
            double accuracyRate;
            if (todayRevenue == 0) {
              accuracyRate = actualCash == 0 ? 100.0 : 0.0;
            } else {
              if (actualCash >= todayRevenue) {
                accuracyRate = (todayRevenue / actualCash) * 100;
              } else {
                accuracyRate = (actualCash / todayRevenue) * 100;
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
                      'Bandingkan uang fisik di laci dengan omzet tercatat di aplikasi hari ini.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Omzet Hari Ini (Sistem):', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            currencyFormatter.format(todayRevenue),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: cashController,
                      decoration: const InputDecoration(
                        labelText: 'Uang Fisik di Laci (Rp)',
                        prefixIcon: Icon(Icons.payments),
                        hintText: 'Masukkan jumlah uang fisik',
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
                        hintText: 'Contoh: Selisih Rp 2.000 karena kembalian...',
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
                    Navigator.of(context).pop();
                    
                    final success = await ref
                        .read(salesHistoryNotifierProvider.notifier)
                        .saveReconciliation(
                          systemRevenue: todayRevenue,
                          actualDrawerCash: actualCash,
                          notes: notesController.text.trim(),
                        );
                    
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Rekonsiliasi kas berhasil disimpan ke Firestore'),
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

