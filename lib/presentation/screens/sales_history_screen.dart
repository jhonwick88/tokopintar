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
        .where((s) => s.status != 'voided')
        .fold(0.0, (sum, s) => sum + s.grandTotal);
    final voidedCount = historyState.filteredSales
        .where((s) => s.status == 'voided')
        .length;
    final totalDiscounts = historyState.filteredSales
        .fold(0.0, (sum, s) => sum + s.discount);

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
                child: Column(
                  children: [
                    // Summary Cards Grid
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
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
                      ),
                    ),
                    const SizedBox(height: 8),
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
                    // Filters row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: historyState.selectedPaymentMethod,
                            decoration: const InputDecoration(
                              labelText: 'Metode Bayar',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('Semua Metode')),
                              DropdownMenuItem(value: 'cash', child: Text('Tunai')),
                              DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                              DropdownMenuItem(value: 'bank', child: Text('Bank/Card')),
                              DropdownMenuItem(value: 'ewallet', child: Text('E-Wallet')),
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
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('Semua Status')),
                              DropdownMenuItem(value: 'completed', child: Text('Completed')),
                              DropdownMenuItem(value: 'voided', child: Text('Voided')),
                              DropdownMenuItem(value: 'refunded', child: Text('Refunded')),
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
                    const SizedBox(height: 12),
                    Expanded(
                      child: historyState.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : historyState.filteredSales.isEmpty
                              ? const Center(child: Text('Tidak ada riwayat transaksi'))
                              : ListView.separated(
                                  itemCount: historyState.filteredSales.length,
                                  separatorBuilder: (c, i) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final sale = historyState.filteredSales[index];
                                    final isSelected = _selectedSale?.invoiceNo == sale.invoiceNo;
                                    
                                    Color statusColor = Colors.green;
                                    if (sale.status == 'voided') {
                                      statusColor = Colors.red;
                                    } else if (sale.status == 'refunded') {
                                      statusColor = Colors.orange;
                                    }

                                    return ListTile(
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
                                    );
                                  },
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
  }) {
    return Card(
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
}
