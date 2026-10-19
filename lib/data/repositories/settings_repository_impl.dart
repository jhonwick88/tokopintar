import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../domain/repositories/settings_repository.dart';
import '../models/settings_model.dart';
import 'dart:developer' as dev;

class SettingsRepositoryImpl implements SettingsRepository {

  @override
  Future<SettingsModel> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Get local rest api url
    final localUrl = prefs.getString('local_rest_api_url') ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:8181';
    
    // 2. Fetch global settings from REST API manually here to avoid circular Riverpod deps
    SettingsModel globalSettings = SettingsModel(
      restApiUrl: localUrl,
      shopName: dotenv.env['SHOP_NAME'] ?? 'Toko Pintar',
      shopAddress: dotenv.env['SHOP_ADDRESS'] ?? 'Jl. Kaliurang KM 5, Yogyakarta',
      shopPhone: dotenv.env['SHOP_PHONE'] ?? '081234567890',
    );
    try {
        final dio = Dio(BaseOptions(baseUrl: localUrl, connectTimeout: const Duration(seconds: 3)));
        final response = await dio.get('/api/company');
        if (response.statusCode == 200 && response.data != null) {
            final success = response.data['success'] as bool? ?? false;
            if (success) {
                final data = response.data['data'];
                if (data != null && data is Map<String, dynamic>) {
                    globalSettings = SettingsModel.fromJson(data);
                }
            }
        }
    } catch(e) {
        dev.log('Error fetching global settings in repository: $e');
    }

    // 3. Load printer settings specific to this local device from SharedPreferences
    final localPrinterType = prefs.getString('local_printer_type') ?? globalSettings.printerType;
    final localPrinterMacAddress = prefs.getString('local_printer_mac_address') ?? globalSettings.printerMacAddress;
    final localPrinterIp = prefs.getString('local_printer_ip') ?? globalSettings.printerIp;
    final localPrinterPort = prefs.getInt('local_printer_port') ?? globalSettings.printerPort;
    final localPrinterPaperSize = prefs.getInt('local_printer_paper_size') ?? globalSettings.printerPaperSize;
    final localPrintReceiptCopies = prefs.getInt('local_print_receipt_copies') ?? globalSettings.printReceiptCopies;
    final localAutoPrintOnCheckout = prefs.getBool('local_auto_print_on_checkout') ?? globalSettings.autoPrintOnCheckout;
    final localEnableFloatingCalculator = prefs.getBool('local_enable_floating_calculator') ?? globalSettings.enableFloatingCalculator;
    final localAllowCashierStockOpname = prefs.getBool('local_allow_cashier_stock_opname') ?? globalSettings.allowCashierStockOpname;

    // 4. Merge global settings with local printer settings
    return globalSettings.copyWith(
      restApiUrl: localUrl,
      printerType: localPrinterType,
      printerMacAddress: localPrinterMacAddress,
      printerIp: localPrinterIp,
      printerPort: localPrinterPort,
      printerPaperSize: localPrinterPaperSize,
      printReceiptCopies: localPrintReceiptCopies,
      autoPrintOnCheckout: localAutoPrintOnCheckout,
      enableFloatingCalculator: localEnableFloatingCalculator,
      allowCashierStockOpname: globalSettings.allowCashierStockOpname || localAllowCashierStockOpname,
    );
  }

  @override
  Future<void> saveSettings(SettingsModel settings) async {
    // 1. Save printer settings locally on this device
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('local_rest_api_url', settings.restApiUrl);
    await prefs.setString('local_printer_type', settings.printerType);
    await prefs.setString('local_printer_mac_address', settings.printerMacAddress);
    await prefs.setString('local_printer_ip', settings.printerIp);
    await prefs.setInt('local_printer_port', settings.printerPort);
    await prefs.setInt('local_printer_paper_size', settings.printerPaperSize);
    await prefs.setInt('local_print_receipt_copies', settings.printReceiptCopies);
    await prefs.setBool('local_auto_print_on_checkout', settings.autoPrintOnCheckout);
    await prefs.setBool('local_enable_floating_calculator', settings.enableFloatingCalculator);
    await prefs.setBool('local_allow_cashier_stock_opname', settings.allowCashierStockOpname);

    // 2. Save global settings (shop name, etc.) to the database via REST API
    try {
        final dio = Dio(BaseOptions(baseUrl: settings.restApiUrl));
        await dio.put('/api/company', data: settings.toJson());
    } catch(e) {
        dev.log('Error saving global settings in repository: $e');
        throw Exception('Gagal menyimpan pengaturan global ke server');
    }
  }
}
