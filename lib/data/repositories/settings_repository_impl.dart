import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/firestore_client.dart';
import '../models/settings_model.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final FirestoreClient _firestoreClient;

  SettingsRepositoryImpl(this._firestoreClient);

  @override
  Future<SettingsModel> getSettings() async {
    // 1. Ambil pengaturan global dari Firestore (Nama toko, alamat, pajak, dll)
    final globalSettings = await _firestoreClient.getSettings();
    
    // 2. Muat pengaturan printer khusus untuk perangkat ini (Local) dari SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final localPrinterType = prefs.getString('local_printer_type') ?? globalSettings.printerType;
    final localPrinterMacAddress = prefs.getString('local_printer_mac_address') ?? globalSettings.printerMacAddress;
    final localPrinterIp = prefs.getString('local_printer_ip') ?? globalSettings.printerIp;
    final localPrinterPort = prefs.getInt('local_printer_port') ?? globalSettings.printerPort;
    final localPrinterPaperSize = prefs.getInt('local_printer_paper_size') ?? globalSettings.printerPaperSize;
    final localPrintReceiptCopies = prefs.getInt('local_print_receipt_copies') ?? globalSettings.printReceiptCopies;
    final localAutoPrintOnCheckout = prefs.getBool('local_auto_print_on_checkout') ?? globalSettings.autoPrintOnCheckout;

    // 3. Gabungkan pengaturan global dengan printer lokal
    return globalSettings.copyWith(
      printerType: localPrinterType,
      printerMacAddress: localPrinterMacAddress,
      printerIp: localPrinterIp,
      printerPort: localPrinterPort,
      printerPaperSize: localPrinterPaperSize,
      printReceiptCopies: localPrintReceiptCopies,
      autoPrintOnCheckout: localAutoPrintOnCheckout,
    );
  }

  @override
  Future<void> saveSettings(SettingsModel settings) async {
    // 1. Simpan pengaturan printer secara lokal di perangkat ini saja
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_printer_type', settings.printerType);
    await prefs.setString('local_printer_mac_address', settings.printerMacAddress);
    await prefs.setString('local_printer_ip', settings.printerIp);
    await prefs.setInt('local_printer_port', settings.printerPort);
    await prefs.setInt('local_printer_paper_size', settings.printerPaperSize);
    await prefs.setInt('local_print_receipt_copies', settings.printReceiptCopies);
    await prefs.setBool('local_auto_print_on_checkout', settings.autoPrintOnCheckout);

    // 2. Simpan semua pengaturan ke Firestore untuk sinkronisasi data global
    await _firestoreClient.saveSettings(settings);
  }
}
