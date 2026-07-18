import 'dart:developer' as dev;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/models/sale_model.dart';
import '../providers/settings_provider.dart';
import '../../domain/services/printer_service.dart';
import 'app_permissions_dialog.dart';

class TransactionSuccessDialog extends ConsumerStatefulWidget {
  final SaleModel sale;
  const TransactionSuccessDialog({super.key, required this.sale});

  @override
  ConsumerState<TransactionSuccessDialog> createState() => _TransactionSuccessDialogState();
}

class _TransactionSuccessDialogState extends ConsumerState<TransactionSuccessDialog> {
  Future<void> _printReceiptDirect(SaleModel sale) async {
    final settings = ref.read(settingsNotifierProvider);

    // Context-aware Bluetooth permissions check
    if (settings.printerType == 'Bluetooth') {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final locGranted = await Permission.locationWhenInUse.isGranted;
        final btConnectGranted = await Permission.bluetoothConnect.isGranted;
        final btScanGranted = await Permission.bluetoothScan.isGranted;

        if (!locGranted || !btConnectGranted || !btScanGranted) {
          if (mounted) {
            await AppPermissionsDialog.show(context);
          }
          final locNow = await Permission.locationWhenInUse.isGranted;
          final btConnectNow = await Permission.bluetoothConnect.isGranted;
          final btScanNow = await Permission.bluetoothScan.isGranted;
          if (!locNow || !btConnectNow || !btScanNow) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Izin Lokasi & Perangkat Sekitar diperlukan untuk mencetak via Bluetooth.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }
        }
      }
    }

    final printBytes = PrinterService.instance.generateReceiptBytes(sale, settings);
    bool success = false;
    
    try {
      if (settings.printerType == 'LAN') {
        success = await PrinterService.instance.printToLan(
          settings.printerIp,
          settings.printerPort,
          printBytes,
          copies: settings.printReceiptCopies,
        );
      } else if (settings.printerType == 'Bluetooth') {
        success = await PrinterService.instance.printToBluetooth(
          settings.printerMacAddress,
          printBytes,
          copies: settings.printReceiptCopies,
        );
      } else if (settings.printerType == 'USB') {
        success = await PrinterService.instance.printToWindows(
          settings.printerMacAddress,
          sale,
          settings,
        );
      } else {
        dev.log('Mock print direct: Invoice ${sale.invoiceNo} printed.');
        success = true;
      }
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Print job berhasil dikirim'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal mengirim print job. Periksa printer Anda.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat mencetak: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _formatRupiah(double val) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(val);
  }

  Widget _buildSummaryRow(String label, String val, {Color? valueColor, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
          val,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.f8) {
            _printReceiptDirect(sale);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.f6) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Container(
          width: 380,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Transaksi Sukses!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                sale.invoiceNo,
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              
              // Details Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Total Belanja', _formatRupiah(sale.grandTotal)),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Total Bayar', _formatRupiah(sale.paidAmount)),
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Kembalian',
                      _formatRupiah(sale.changeAmount),
                      valueColor: Colors.green,
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        _printReceiptDirect(sale);
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Cetak Ulang(F8)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Selesai(F6)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
