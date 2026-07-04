import 'dart:convert';
import 'dart:io';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/settings_model.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._internal();
  PrinterService._internal();

  /// Generates the ESC/POS printing bytes for a Sale transaction.
  List<int> generateReceiptBytes(SaleModel sale, SettingsModel settings) {
    final builder = EscPosBuilder();

    // 1. Initialize
    builder.initialize();

    // 2. Header (Double size, Centered, Bold)
    builder.alignCenter();
    builder.boldOn();
    builder.doubleSizeOn();
    builder.text(settings.shopName);
    builder.doubleSizeOff();
    builder.boldOff();

    // Shop details
    builder.text(settings.shopAddress);
    builder.text('Telp: ${settings.shopPhone}');
    builder.text(settings.receiptHeader);
    builder.feed(1);

    // 3. Invoice Metadata (Left aligned)
    builder.alignLeft();
    builder.text('Invoice : ${sale.invoiceNo}');
    builder.text('Tanggal : ${_formatDateTime(sale.date)}');
    builder.text('Kasir   : ${sale.cashier}');
    builder.line(); // Divider ---

    // 4. Sold Items
    for (var item in sale.items) {
      // Line 1: Item Name
      builder.text(item.itemName);
      
      // Line 2: Qty x Price and Subtotal aligned
      final qtyPriceStr = '  ${item.qty} x ${_formatCurrency(item.price)}';
      final itemSubtotalStr = _formatCurrency(item.subtotal);
      builder.row(qtyPriceStr, itemSubtotalStr);
      
      if (item.note.isNotEmpty) {
        builder.text('  * Note: ${item.note}');
      }
    }
    builder.line(); // Divider ---

    // 5. Totals
    builder.row('Subtotal', _formatCurrency(sale.subtotal));
    if (sale.discount > 0) {
      builder.row('Diskon', '-${_formatCurrency(sale.discount)}');
    }
    builder.boldOn();
    builder.row('Total', _formatCurrency(sale.grandTotal));
    builder.boldOff();
    builder.feed(1);

    // Payments
    builder.row('Bayar (${sale.paymentMethod.toUpperCase()})', _formatCurrency(sale.paidAmount));
    builder.row('Kembali', _formatCurrency(sale.changeAmount));
    builder.line();

    // 6. Footer
    builder.alignCenter();
    builder.text(settings.receiptFooter);
    builder.text('Terima Kasih');
    
    // 7. Cut paper and feed
    builder.feed(3);
    builder.cut();

    return builder.bytes;
  }

  /// Sends bytes to a Network (LAN) Printer
  Future<bool> printToLan(String ip, int port, List<int> bytes) async {
    if (kIsWeb) {
      dev.log('LAN socket printing not supported directly in web browsers.');
      return false;
    }
    try {
      dev.log('Connecting to LAN printer at $ip:$port');
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 3));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      dev.log('LAN print sent successfully.');
      return true;
    } catch (e) {
      dev.log('LAN printing failed: $e');
      return false;
    }
  }

  /// Sends bytes to a Bluetooth Printer
  Future<bool> printToBluetooth(String macAddress, List<int> bytes) async {
    if (kIsWeb) {
      dev.log('Bluetooth printing not supported in web browsers.');
      return false;
    }
    if (macAddress.isEmpty) {
      dev.log('Bluetooth printing failed: Alamat MAC kosong.');
      return false;
    }
    try {
      final bool isGranted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!isGranted) {
        dev.log('Bluetooth printing failed: Izin Bluetooth tidak diberikan.');
        return false;
      }

      dev.log('Checking Bluetooth connection status...');
      final bool isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!isConnected) {
        dev.log('Connecting to Bluetooth printer at $macAddress...');
        final bool connectResult = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
        if (!connectResult) {
          dev.log('Failed to connect to Bluetooth printer.');
          return false;
        }
      }
      dev.log('Sending print job to Bluetooth printer...');
      final bool printResult = await PrintBluetoothThermal.writeBytes(bytes);
      dev.log('Bluetooth print result: $printResult');
      return printResult;
    } catch (e) {
      dev.log('Bluetooth printing failed: $e');
      return false;
    }
  }

  /// Format Date Time to DD/MM/YYYY HH:mm
  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$min';
  }

  /// Formats currency with dots, e.g. 100000 -> 100.000
  String _formatCurrency(double amount) {
    final value = amount.toInt();
    final str = value.toString();
    final regExp = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(regExp, (Match m) => '${m[1]}.');
  }
}

/// Helper class to construct raw ESC/POS byte streams for 80mm printers (48 chars wide).
class EscPosBuilder {
  final List<int> _bytes = [];

  List<int> get bytes => _bytes;

  void initialize() {
    // ESC @ (Initialize printer)
    _bytes.addAll([0x1B, 0x40]);
  }

  void alignLeft() {
    // ESC a 0 (Align left)
    _bytes.addAll([0x1B, 0x61, 0x00]);
  }

  void alignCenter() {
    // ESC a 1 (Align center)
    _bytes.addAll([0x1B, 0x61, 0x01]);
  }

  void alignRight() {
    // ESC a 2 (Align right)
    _bytes.addAll([0x1B, 0x61, 0x02]);
  }

  void boldOn() {
    // ESC E 1 (Bold mode on)
    _bytes.addAll([0x1B, 0x45, 0x01]);
  }

  void boldOff() {
    // ESC E 0 (Bold mode off)
    _bytes.addAll([0x1B, 0x45, 0x00]);
  }

  void doubleSizeOn() {
    // GS ! 0x11 (Double height, double width)
    _bytes.addAll([0x1D, 0x21, 0x11]);
  }

  void doubleSizeOff() {
    // GS ! 0x00 (Normal size)
    _bytes.addAll([0x1D, 0x21, 0x00]);
  }

  void text(String text) {
    // Write text encoded in latin1 or ascii
    _bytes.addAll(latin1.encode('$text\n'));
  }

  void feed(int lines) {
    // ESC d (Feed n lines)
    _bytes.addAll([0x1B, 0x64, lines]);
  }

  void line() {
    // 80mm printers generally support 48 columns
    text('------------------------------------------------');
  }

  /// Aligns leftText to the left, rightText to the right, padding with spaces in between.
  void row(String leftText, String rightText, {int totalWidth = 48}) {
    final leftLength = leftText.length;
    final rightLength = rightText.length;
    
    if (leftLength + rightLength >= totalWidth) {
      // If it doesn't fit, print leftText on one line and rightText right-aligned on the next
      text(leftText);
      final spacesNeeded = totalWidth - rightLength;
      final spaces = ' ' * (spacesNeeded > 0 ? spacesNeeded : 0);
      text('$spaces$rightText');
    } else {
      final spacesNeeded = totalWidth - leftLength - rightLength;
      final spaces = ' ' * spacesNeeded;
      text('$leftText$spaces$rightText');
    }
  }

  void cut() {
    // GS V 65 0 (Cut paper)
    _bytes.addAll([0x1D, 0x56, 0x41, 0x00]);
  }
}
