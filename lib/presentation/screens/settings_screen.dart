import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/settings_model.dart';
import '../../domain/services/printer_service.dart';
import '../providers/auth_provider.dart';
import '../providers/license_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/main_layout.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/app_permissions_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'quick_add_item_settings_screen.dart';
import '../../core/utils/file_saver_helper.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  late TextEditingController _shopNameController;
  late TextEditingController _shopAddressController;
  late TextEditingController _shopPhoneController;
  late TextEditingController _receiptHeaderController;
  late TextEditingController _receiptFooterController;
  late TextEditingController _apiUrlController;
  late TextEditingController _printerIpController;
  late TextEditingController _printerPortController;
  
  // Professional additions
  late TextEditingController _adminPinController;
  late TextEditingController _taxPercentageController;
  late TextEditingController _serviceChargePercentageController;
  late TextEditingController _licenseKeyController;
  
  bool _enableTax = false;
  bool _enableServiceCharge = false;
  int _printerPaperSize = 58;
  int _printReceiptCopies = 1;
  bool _autoPrintOnCheckout = false;
  bool _enableFloatingCalculator = false;
  bool _allowCashierStockOpname = false;

  String _printerType = 'LAN';
  String _printerMacAddress = '';
  List<BluetoothInfo> _bluetoothDevices = [];
  bool _isScanningBluetooth = false;
  List<Printer> _windowsPrinters = [];
  bool _isScanningPrinters = false;
  bool _isTestingPrinter = false;
  bool _isEditingUnlocked = false;
  bool _isTestingConnection = false;
  String? _connectionStatus;
  bool _allPermissionsGranted = true;
  bool _isUpdatingLicense = false;
  bool _isRefreshingLicense = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider);
    _shopNameController = TextEditingController(text: settings.shopName);
    _shopAddressController = TextEditingController(text: settings.shopAddress);
    _shopPhoneController = TextEditingController(text: settings.shopPhone);
    _receiptHeaderController = TextEditingController(text: settings.receiptHeader);
    _receiptFooterController = TextEditingController(text: settings.receiptFooter);
    _apiUrlController = TextEditingController(text: settings.restApiUrl);
    _printerIpController = TextEditingController(text: settings.printerIp);
    _printerPortController = TextEditingController(text: settings.printerPort.toString());
    _printerType = settings.printerType;
    _printerMacAddress = settings.printerMacAddress;
    
    _adminPinController = TextEditingController(text: settings.adminPin);
    _taxPercentageController = TextEditingController(text: settings.taxPercentage.toString());
    _serviceChargePercentageController = TextEditingController(text: settings.serviceChargePercentage.toString());
    _licenseKeyController = TextEditingController();
    _enableTax = settings.enableTax;
    _enableServiceCharge = settings.enableServiceCharge;
    _printerPaperSize = settings.printerPaperSize;
    _printReceiptCopies = settings.printReceiptCopies;
    _autoPrintOnCheckout = settings.autoPrintOnCheckout;
    _enableFloatingCalculator = settings.enableFloatingCalculator;
    _allowCashierStockOpname = settings.allowCashierStockOpname;

    // Check if the current user is already an Admin to unlock editing
    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser?.role == 'admin') {
      _isEditingUnlocked = true;
    }

    if (_printerType == 'Bluetooth') {
      Future.delayed(Duration.zero, () {
        _scanBluetoothDevices();
      });
    } else if (_printerType == 'USB') {
      Future.delayed(Duration.zero, () {
        _scanWindowsPrinters();
      });
    }
    _checkAppPermissions();
    _loadFreshSettings();
  }

  Future<void> _loadFreshSettings() async {
    try {
      final fresh = await ref.read(settingsRepositoryProvider).getSettings();
      if (mounted) {
        setState(() {
          _shopNameController.text = fresh.shopName;
          _shopAddressController.text = fresh.shopAddress;
          _shopPhoneController.text = fresh.shopPhone;
          _receiptHeaderController.text = fresh.receiptHeader;
          _receiptFooterController.text = fresh.receiptFooter;
          if (fresh.adminPin.isNotEmpty) {
            _adminPinController.text = fresh.adminPin;
          }
          _enableTax = fresh.enableTax;
          _taxPercentageController.text = fresh.taxPercentage.toString();
          _enableServiceCharge = fresh.enableServiceCharge;
          _serviceChargePercentageController.text = fresh.serviceChargePercentage.toString();
          _allowCashierStockOpname = fresh.allowCashierStockOpname;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkAppPermissions() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      if (mounted) {
        setState(() {
          _allPermissionsGranted = true;
        });
      }
      return;
    }

    final camera = await Permission.camera.isGranted;
    final location = await Permission.locationWhenInUse.isGranted;
    final mic = await Permission.microphone.isGranted;
    final btConnect = await Permission.bluetoothConnect.isGranted;
    final btScan = await Permission.bluetoothScan.isGranted;

    if (mounted) {
      setState(() {
        _allPermissionsGranted = camera && location && mic && btConnect && btScan;
      });
    }
  }

  Future<void> _scanBluetoothDevices() async {
    // Check Mobile Permissions for Bluetooth Connection & Location
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
                content: Text('Izin Lokasi & Perangkat Sekitar diperlukan untuk mendeteksi printer Bluetooth.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }
    }

    setState(() {
      _isScanningBluetooth = true;
    });
    try {
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      setState(() {
        _bluetoothDevices = devices;
      });
      if (_printerMacAddress.isEmpty && devices.isNotEmpty) {
        _printerMacAddress = devices.first.macAdress;
      }
    } catch (e) {
      debugPrint('Gagal memindai perangkat Bluetooth: $e');
    } finally {
      setState(() {
        _isScanningBluetooth = false;
      });
    }
  }

  Future<void> _scanWindowsPrinters() async {
    setState(() {
      _isScanningPrinters = true;
    });
    try {
      final printers = await Printing.listPrinters();
      setState(() {
        _windowsPrinters = printers;
      });
      if (_printerMacAddress.isEmpty && printers.isNotEmpty) {
        _printerMacAddress = printers.first.name;
      }
    } catch (e) {
      debugPrint('Gagal memindai printer Windows: $e');
    } finally {
      setState(() {
        _isScanningPrinters = false;
      });
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    _receiptHeaderController.dispose();
    _receiptFooterController.dispose();
    _apiUrlController.dispose();
    _printerIpController.dispose();
    _printerPortController.dispose();
    _adminPinController.dispose();
    _taxPercentageController.dispose();
    _serviceChargePercentageController.dispose();
    _licenseKeyController.dispose();
    super.dispose();
  }

  void _requestAdminUnlock() {
    final settings = ref.read(settingsNotifierProvider);
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Otorisasi Admin'),
          content: TextField(
            controller: pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Masukkan PIN Admin',
              hintText: 'Masukkan PIN pengelola',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (pinController.text == settings.adminPin) {
                  setState(() {
                    _isEditingUnlocked = true;
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Akses Pengaturan Terbuka'), backgroundColor: Colors.green),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN Salah!'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Verifikasi'),
            ),
          ],
        );
      },
    );
  }

  void _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final currentSettings = ref.read(settingsNotifierProvider);
    final updated = currentSettings.copyWith(
      shopName: _shopNameController.text,
      shopAddress: _shopAddressController.text,
      shopPhone: _shopPhoneController.text,
      receiptHeader: _receiptHeaderController.text,
      receiptFooter: _receiptFooterController.text,
      restApiUrl: _apiUrlController.text,
      printerIp: _printerIpController.text,
      printerPort: int.tryParse(_printerPortController.text) ?? 9100,
      printerType: _printerType,
      printerMacAddress: _printerMacAddress,
      adminPin: _adminPinController.text,
      enableTax: _enableTax,
      taxPercentage: double.tryParse(_taxPercentageController.text) ?? 0.0,
      enableServiceCharge: _enableServiceCharge,
      serviceChargePercentage: double.tryParse(_serviceChargePercentageController.text) ?? 0.0,
      printerPaperSize: _printerPaperSize,
      printReceiptCopies: _printReceiptCopies,
      autoPrintOnCheckout: _autoPrintOnCheckout,
      enableFloatingCalculator: _enableFloatingCalculator,
      allowCashierStockOpname: _allowCashierStockOpname,
    );

    await ref.read(settingsNotifierProvider.notifier).updateSettings(updated);
    
    // Log activity
    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser != null) {
      await ref.read(auditRepositoryProvider).logActivity(
            currentUser.uid,
            currentUser.username,
            'update_settings',
            'Updated POS store and printer configuration settings',
          );
    }

    if (currentUser?.role != 'admin') {
      if (mounted) {
        setState(() {
          _isEditingUnlocked = false;
        });
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan berhasil disimpan'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _testApiConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });
    final url = _apiUrlController.text.trim();
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      ));
      final response = await dio.get('$url/api/categories');
      if (response.statusCode == 200) {
        setState(() {
          _connectionStatus = 'connected';
        });

        // Automatically pull and sync company settings from server
        try {
          final compRes = await dio.get('$url/api/company');
          if (compRes.statusCode == 200 && compRes.data != null) {
            final success = compRes.data['success'] as bool? ?? false;
            if (success) {
              final data = compRes.data['data'];
              if (data != null && data is Map<String, dynamic>) {
                final serverSettings = SettingsModel.fromJson(data);
                if (mounted) {
                  setState(() {
                    _shopNameController.text = serverSettings.shopName;
                    _shopAddressController.text = serverSettings.shopAddress;
                    _shopPhoneController.text = serverSettings.shopPhone;
                    _receiptHeaderController.text = serverSettings.receiptHeader;
                    _receiptFooterController.text = serverSettings.receiptFooter;
                    if (serverSettings.adminPin.isNotEmpty) {
                      _adminPinController.text = serverSettings.adminPin;
                    }
                    _enableTax = serverSettings.enableTax;
                    _taxPercentageController.text = serverSettings.taxPercentage.toString();
                    _enableServiceCharge = serverSettings.enableServiceCharge;
                    _serviceChargePercentageController.text = serverSettings.serviceChargePercentage.toString();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Koneksi berhasil! Data toko "${serverSettings.shopName}" disinkronkan dari server.'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Gagal mengambil data toko saat tes koneksi: $e');
        }
      } else {
        setState(() {
          _connectionStatus = 'error';
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'disconnected';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  Widget _buildConnectionStatusFeedback() {
    Color color;
    IconData icon;
    String text;

    switch (_connectionStatus) {
      case 'connected':
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Koneksi Berhasil! Terhubung ke Server & data toko disinkronkan.';
        break;
      case 'error':
        color = Colors.orange;
        icon = Icons.warning;
        text = 'Respon Invalid: Server terjangkau tetapi mengembalikan error status code.';
        break;
      case 'disconnected':
      default:
        color = Colors.red;
        icon = Icons.error;
        text = 'Koneksi Gagal: Server REST API tidak terjangkau. Periksa alamat IP / port.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _printTestPage() async {
    final builder = EscPosBuilder();
    builder.initialize();
    builder.alignCenter();
    builder.boldOn();
    builder.text('TEST PRINT RECEIPT');
    builder.text(_shopNameController.text);
    builder.boldOff();
    builder.text('Printer Type: $_printerType');
    if (_printerType == 'LAN') {
      builder.text('IP: ${_printerIpController.text}:${_printerPortController.text}');
    } else if (_printerType == 'Bluetooth') {
      builder.text('MAC: $_printerMacAddress');
    }
    builder.line();
    builder.text('Printer ESC/POS 80mm works!');
    builder.feed(3);
    builder.cut();

    if (_printerType == 'LAN') {
      final success = await PrinterService.instance.printToLan(
        _printerIpController.text,
        int.tryParse(_printerPortController.text) ?? 9100,
        builder.bytes,
      );
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test print terkirim ke printer LAN'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Koneksi printer LAN gagal!'), backgroundColor: Colors.red),
        );
      }
    } else if (_printerType == 'Bluetooth') {
      setState(() {
        _isTestingPrinter = true;
      });
      final success = await PrinterService.instance.printToBluetooth(
        _printerMacAddress,
        builder.bytes,
      );
      setState(() {
        _isTestingPrinter = false;
      });
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test print terkirim ke printer Bluetooth'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Koneksi printer Bluetooth gagal! Pastikan perangkat aktif.'), backgroundColor: Colors.red),
        );
      }
    } else if (_printerType == 'USB') {
      setState(() {
        _isTestingPrinter = true;
      });
      final settings = ref.read(settingsNotifierProvider);
      final success = await PrinterService.instance.printTestToWindows(
        _printerMacAddress,
        settings,
      );
      setState(() {
        _isTestingPrinter = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          success
              ? const SnackBar(content: Text('Test print terkirim ke printer USB (Windows)'), backgroundColor: Colors.green)
              : const SnackBar(content: Text('Pencetakan printer USB gagal! Pastikan nama printer benar.'), backgroundColor: Colors.red),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test print dihasilkan (${builder.bytes.length} bytes). Koneksi printer mock.'),
          backgroundColor: Colors.indigo,
        ),
      );
    }
  }

  void _confirmAndLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Keluar'),
          content: const Text('Apakah Anda yakin ingin keluar dari akun kasir saat ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(authNotifierProvider.notifier).logout();
              },
              child: const Text('Keluar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final isMobile = width < 600;
    final currentUser = ref.watch(authNotifierProvider).currentUser;
    final isAdmin = currentUser?.role == 'admin';
    return MainLayout(
      currentRoute: '/settings',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: false,
          actions: [
            if (!_isEditingUnlocked)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _requestAdminUnlock,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Buka Kunci Admin'),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade600, width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_open, color: Colors.green, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Mode Admin Aktif',
                        style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: isMobile ? 12 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isEditingUnlocked)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Anda masuk sebagai Kasir. Pengaturan dikunci. Klik tombol "Buka Kunci Admin" di atas untuk melakukan perubahan.',
                            style: TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                // Section 1: Shop Profiling
                _buildCardSection(
                  title: 'Profil Toko',
                  icon: Icons.store,
                  children: [
                    _buildTextField(
                      controller: _shopNameController,
                      label: 'Nama Toko',
                      validator: (val) => val!.isEmpty ? 'Nama toko wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _shopAddressController,
                      label: 'Alamat Toko',
                      validator: (val) => val!.isEmpty ? 'Alamat wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _shopPhoneController,
                      label: 'Nomor Telpon Toko',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _receiptHeaderController,
                            label: 'Header Nota (Slogan)',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _receiptFooterController,
                            label: 'Footer Nota (Terima Kasih)',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Section 2: REST API
                _buildCardSection(
                  title: 'Koneksi Server',
                  icon: _isTestingConnection
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : Icons.api_rounded,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _apiUrlController,
                            label: 'Base URL Server',
                            hint: 'http://localhost:8181',
                            validator: (val) => val!.isEmpty ? 'URL REST API wajib diisi' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: (_isTestingConnection || !_isEditingUnlocked) ? null : _testApiConnection,
                          icon: const Icon(Icons.sync, size: 18),
                          label: const Text('Tes & Sinkron'),
                        ),
                      ],
                    ),
                    if (_connectionStatus != null) ...[
                      const SizedBox(height: 16),
                      _buildConnectionStatusFeedback(),
                    ]
                  ],
                ),
                const SizedBox(height: 24),

                // Section: Keamanan
                _buildCardSection(
                  title: 'Keamanan Akses',
                  icon: Icons.security,
                  children: [

                    _buildTextField(
                      controller: _adminPinController,
                      label: 'PIN Otorisasi Admin',
                      hint: '1234',
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      validator: (val) => val!.isEmpty ? 'PIN wajib diisi' : null,
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: _allPermissionsGranted
                            ? Colors.green.withOpacity(0.05)
                            : Colors.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _allPermissionsGranted
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onTap: () async {
                          await AppPermissionsDialog.show(context);
                          _checkAppPermissions();
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _allPermissionsGranted
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _allPermissionsGranted ? Icons.security_rounded : Icons.gpp_maybe_rounded,
                            color: _allPermissionsGranted ? Colors.green : Colors.red,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Kelola Izin Aplikasi',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Kelola Izin Kamera, Bluetooth, & Lokasi',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: Icon(
                          _allPermissionsGranted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: _allPermissionsGranted ? Colors.green : Colors.red,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.inventory_outlined, color: Colors.orange, size: 20),
                      ),
                      title: const Text(
                        'Izinkan Kasir Melakukan Stok Opname',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Jika aktif, staf/kasir dapat mengakses menu Stok Opname untuk memperbarui stok barang fisik.',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                      value: _allowCashierStockOpname,
                      onChanged: _isEditingUnlocked
                          ? (val) {
                              setState(() {
                                _allowCashierStockOpname = val;
                              });
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Section: Pajak & Layanan
                _buildCardSection(
                  title: 'Pajak & Layanan',
                  icon: Icons.receipt_long,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Aktifkan Pajak (PPN)', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Terapkan pajak penjualan pada transaksi checkout'),
                            value: _enableTax,
                            onChanged: _isEditingUnlocked
                                ? (val) {
                                    setState(() {
                                      _enableTax = val;
                                    });
                                  }
                                : null,
                          ),
                        ),
                        if (_enableTax) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _taxPercentageController,
                              label: 'Persentase Pajak (%)',
                              hint: '11',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Aktifkan Biaya Layanan', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Terapkan biaya layanan katering / restoran'),
                            value: _enableServiceCharge,
                            onChanged: _isEditingUnlocked
                                ? (val) {
                                    setState(() {
                                      _enableServiceCharge = val;
                                    });
                                  }
                                : null,
                          ),
                        ),
                        if (_enableServiceCharge) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _serviceChargePercentageController,
                              label: 'Persentase Layanan (%)',
                              hint: '5',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Section 3: ESC/POS Thermal Printer
                _buildCardSection(
                  title: 'Pengaturan Printer Kasir',
                  icon: Icons.print,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: isDesktop ? 3 : 3,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _printerType,
                            decoration: const InputDecoration(labelText: 'Tipe Koneksi Printer'),
                            items: ['LAN', 'Bluetooth', 'USB', 'Browser'].map((type) {
                              return DropdownMenuItem(value: type, child: Text(type));
                            }).toList(),
                            onChanged: _isEditingUnlocked
                                ? (val) {
                                    if (val != null) {
                                      setState(() {
                                        _printerType = val;
                                        if (_printerType == 'Bluetooth') {
                                          _scanBluetoothDevices();
                                        } else if (_printerType == 'USB') {
                                          _scanWindowsPrinters();
                                        }
                                      });
                                    }
                                  }
                                : null,
                          ),
                        ),
                        if (_printerType == 'LAN') ...[
                          const SizedBox(width: 16),
                          Expanded(
                            flex: isDesktop ? 1 : 2,
                            child: _buildTextField(
                              controller: _printerPortController,
                              label: 'Port',
                              hint: '9100',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_printerType == 'LAN') ...[
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _printerIpController,
                        label: 'IP Address Printer',
                        hint: '192.168.1.100',
                      ),
                    ],
                    if (_printerType == 'Bluetooth') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _bluetoothDevices.any((device) => device.macAdress == _printerMacAddress) ? _printerMacAddress : null,
                              decoration: const InputDecoration(
                                labelText: 'Pilih Printer Bluetooth',
                                prefixIcon: Icon(Icons.bluetooth),
                              ),
                              items: _bluetoothDevices.map((device) {
                                return DropdownMenuItem<String>(
                                  value: device.macAdress,
                                  child: Text(
                                    '${device.name} (${device.macAdress})',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                              }).toList(),
                              onChanged: _isEditingUnlocked
                                  ? (val) {
                                      if (val != null) {
                                        setState(() {
                                          _printerMacAddress = val;
                                        });
                                      }
                                    }
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: _isScanningBluetooth
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.refresh),
                            onPressed: (_isScanningBluetooth || !_isEditingUnlocked)
                                ? null
                                : _scanBluetoothDevices,
                            tooltip: 'Pindai Perangkat',
                          ),
                        ],
                      ),
                    ],
                    if (_printerType == 'USB') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _windowsPrinters.any((p) => p.name == _printerMacAddress) ? _printerMacAddress : null,
                              decoration: const InputDecoration(
                                labelText: 'Pilih Printer USB (Windows)',
                                prefixIcon: Icon(Icons.print_outlined),
                              ),
                              items: _windowsPrinters.map((printer) {
                                return DropdownMenuItem<String>(
                                  value: printer.name,
                                  child: Text(
                                    printer.name,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                              }).toList(),
                              onChanged: _isEditingUnlocked
                                  ? (val) {
                                      if (val != null) {
                                        setState(() {
                                          _printerMacAddress = val;
                                        });
                                      }
                                    }
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: _isScanningPrinters
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.refresh),
                            onPressed: (_isScanningPrinters || !_isEditingUnlocked)
                                ? null
                                : _scanWindowsPrinters,
                            tooltip: 'Pindai Printer Windows',
                          ),
                        ],
                      ),
                    ],
                  const Divider(),
                  const SizedBox(height: 8),
                   if (isDesktop) ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _printerPaperSize,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Lebar Kertas Thermal'),
                            items: const [
                              DropdownMenuItem(value: 58, child: Text('58 mm (Kecil)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 80, child: Text('80 mm (Standar)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                            ],
                            onChanged: _isEditingUnlocked
                                ? (val) {
                                    if (val != null) {
                                      setState(() {
                                        _printerPaperSize = val;
                                      });
                                    }
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _printReceiptCopies,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Jumlah Cetak Nota (Rangkap)'),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1 Lembar', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 2, child: Text('2 Lembar (Kasir + Pelanggan)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 3, child: Text('3 Lembar', overflow: TextOverflow.ellipsis, maxLines: 1)),
                            ],
                            onChanged: _isEditingUnlocked
                                ? (val) {
                                    if (val != null) {
                                      setState(() {
                                        _printReceiptCopies = val;
                                      });
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    DropdownButtonFormField<int>(
                      value: _printerPaperSize,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Lebar Kertas Thermal'),
                      items: const [
                        DropdownMenuItem(value: 58, child: Text('58 mm (Kecil)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 80, child: Text('80 mm (Standar)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ],
                      onChanged: _isEditingUnlocked
                          ? (val) {
                              if (val != null) {
                                setState(() {
                                  _printerPaperSize = val;
                                });
                              }
                            }
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _printReceiptCopies,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Jumlah Cetak Nota (Rangkap)'),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 Lembar', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 2, child: Text('2 Lembar (Kasir + Pelanggan)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 3, child: Text('3 Lembar', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ],
                      onChanged: _isEditingUnlocked
                          ? (val) {
                              if (val != null) {
                                setState(() {
                                  _printReceiptCopies = val;
                                });
                              }
                            }
                          : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cetak Nota Otomatis (Auto-Print)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Otomatis kirim perintah print setelah transaksi checkout berhasil'),
                    value: _autoPrintOnCheckout,
                    onChanged: _isEditingUnlocked
                        ? (val) {
                            setState(() {
                              _autoPrintOnCheckout = val;
                            });
                          }
                        : null,
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 16 : 24),

                // Section 5: Lisensi & Fitur Aplikasi (Level Admin)
                if (isAdmin) ...[
                  _buildLicenseSettings(),
                  SizedBox(height: isMobile ? 16 : 24),
                  _buildDatabaseSettings(),
                  SizedBox(height: isMobile ? 20 : 32),
                ],

                // Section 4: Aplikasi & Sistem
                _buildCardSection(
                  title: 'Aplikasi & Sistem',
                  icon: Icons.settings_display_rounded,
                  children: [
                    ListTile(
                      dense: isMobile,
                      contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
                      leading: Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: (themeMode == ThemeMode.dark ? Colors.amber : Colors.blue).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                          size: isMobile ? 18 : 20,
                          color: themeMode == ThemeMode.dark ? Colors.amber : Colors.blue,
                        ),
                      ),
                      title: Text(
                        themeMode == ThemeMode.dark ? 'Mode Gelap Aktif' : 'Mode Terang Aktif',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: isMobile ? 13.5 : 14.5),
                      ),
                      subtitle: Text(
                        themeMode == ThemeMode.dark ? 'Tampilan layar gelap' : 'Tampilan layar cerah',
                        style: TextStyle(fontSize: isMobile ? 11 : 12),
                      ),
                      trailing: Switch(
                        value: themeMode == ThemeMode.dark,
                        onChanged: (val) {
                          ref.read(themeModeProvider.notifier).state =
                              val ? ThemeMode.dark : ThemeMode.light;
                        },
                      ),
                    ),
                    Divider(height: isMobile ? 12 : 16, indent: isMobile ? 42 : 48),
                    ListTile(
                      dense: isMobile,
                      contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
                      leading: Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.calculate_rounded, color: Colors.blue, size: isMobile ? 18 : 20),
                      ),
                      title: Text(
                        'Kalkulator Melayang (POS)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: isMobile ? 13.5 : 14.5),
                      ),
                      subtitle: Text(
                        'Kalkulator mini geser di kasir',
                        style: TextStyle(fontSize: isMobile ? 11 : 12),
                      ),
                      trailing: Switch(
                        value: _enableFloatingCalculator,
                        onChanged: _isEditingUnlocked
                            ? (val) {
                                setState(() {
                                  _enableFloatingCalculator = val;
                                });
                              }
                            : null,
                      ),
                    ),
                    Divider(height: isMobile ? 12 : 16, indent: isMobile ? 42 : 48),
                    ListTile(
                      dense: isMobile,
                      contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
                      leading: Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.bolt, color: Colors.amber[800], size: isMobile ? 18 : 20),
                      ),
                      title: Text(
                        'Quick Add Item',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 13.5 : 14.5),
                      ),
                      subtitle: Text(
                        'Tombol cepat untuk produk kasir',
                        style: TextStyle(fontSize: isMobile ? 11 : 12),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const QuickAddItemSettingsScreen()),
                        );
                      },
                    ),
                    Divider(height: isMobile ? 12 : 16, indent: isMobile ? 42 : 48),
                    ListTile(
                      dense: isMobile,
                      contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
                      leading: Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.rocket_launch, color: Colors.purple, size: isMobile ? 18 : 20),
                      ),
                      title: Text(
                        'Hubungi Developer',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 13.5 : 14.5),
                      ),
                      subtitle: Text(
                        'Bantuan & kendala aplikasi',
                        style: TextStyle(fontSize: isMobile ? 11 : 12),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        context.push('/developer-contact');
                      },
                    ),
                    Divider(height: isMobile ? 12 : 16, indent: isMobile ? 42 : 48),
                    ListTile(
                      dense: isMobile,
                      contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
                      leading: Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.logout, color: Colors.red, size: isMobile ? 18 : 20),
                      ),
                      title: Text(
                        'Logout Kasir',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: isMobile ? 13.5 : 14.5),
                      ),
                      subtitle: Text(
                        'Akhiri sesi aktif kasir saat ini',
                        style: TextStyle(fontSize: isMobile ? 11 : 12),
                      ),
                      onTap: () => _confirmAndLogout(context),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 20 : 32),

                // Submit Buttons
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isEditingUnlocked ? _saveSettings : null,
                        icon: const Icon(Icons.save),
                        label: const Text('Simpan Pengaturan', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isTestingPrinter ? null : _printTestPage,
                        icon: _isTestingPrinter
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.receipt_long_rounded),
                        label: const Text('Cetak Halaman Uji'),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isTestingPrinter ? null : _printTestPage,
                        icon: _isTestingPrinter
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.receipt_long_rounded),
                        label: const Text('Cetak Hal Uji'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isEditingUnlocked ? _saveSettings : null,
                        icon: const Icon(Icons.save),
                        label: const Text('Simpan'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseSettings() {
    final licenseState = ref.watch(licenseProvider);
    final features = licenseState.features;
    final isActivated = licenseState.isActivated;
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return _buildCardSection(
      title: 'Lisensi & Fitur Aplikasi',
      icon: Icons.verified_user_rounded,
      children: [
        // Status Bar
        Container(
          padding: EdgeInsets.all(isMobile ? 10 : 16),
          decoration: BoxDecoration(
            color: isActivated ? Colors.green.withValues(alpha: 0.08) : Colors.amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActivated ? Colors.green.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.4),
            ),
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isActivated ? Colors.green.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isActivated ? Icons.verified_rounded : Icons.warning_amber_rounded,
                            color: isActivated ? Colors.green.shade700 : Colors.amber.shade800,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isActivated ? 'Lisensi Aktif' : 'Lisensi Belum Terpasang',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isActivated ? Colors.green.shade800 : Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isActivated ? Colors.green.shade700 : Colors.amber.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isActivated ? (features['tier']?.toString().toUpperCase() ?? 'PRO / ACTIVE') : 'UNREGISTERED',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: _isRefreshingLicense ? null : _handleRefreshLicense,
                          icon: _isRefreshingLicense
                              ? const SizedBox(
                                  width: 11,
                                  height: 11,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync_rounded, size: 14),
                          label: const Text('Sinkron', style: TextStyle(fontSize: 10.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isActivated
                          ? 'Perangkat ini terdaftar secara resmi dengan fitur penuh.'
                          : 'Mode terbatas. Masukkan License Key untuk membuka fitur.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isActivated ? Colors.green.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActivated ? Icons.verified_rounded : Icons.warning_amber_rounded,
                        color: isActivated ? Colors.green.shade700 : Colors.amber.shade800,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isActivated ? 'Lisensi Aktif' : 'Lisensi Belum Terpasang',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isActivated ? Colors.green.shade800 : Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isActivated ? Colors.green.shade700 : Colors.amber.shade700,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isActivated ? (features['tier']?.toString().toUpperCase() ?? 'PRO / ACTIVE') : 'UNREGISTERED',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isActivated
                                ? 'Perangkat ini terdaftar secara resmi. Fitur di bawah ini aktif sesuai paket lisensi Anda.'
                                : 'Aplikasi berjalan dalam mode terbatas. Masukkan License Key untuk mengaktifkan modul lengkap.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isRefreshingLicense ? null : _handleRefreshLicense,
                      icon: _isRefreshingLicense
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 16),
                      label: const Text('Sinkron', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
        ),
        if (isActivated) ...[
          SizedBox(height: isMobile ? 10 : 16),
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.badge_outlined, size: isMobile ? 16 : 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      isMobile ? 'Detail Lisensi' : 'Detail Identitas Lisensi Pelanggan',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 13),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 8 : 12),
                if (isMobile)
                  Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (licenseState.licenseId != null && licenseState.licenseId!.isNotEmpty)
                            Expanded(
                              child: _buildLicenseInfoItem(
                                label: 'ID LISENSI',
                                value: licenseState.licenseId!,
                                allowCopy: true,
                                isMobile: true,
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (licenseState.customerId != null && licenseState.customerId!.isNotEmpty)
                            Expanded(
                              child: _buildLicenseInfoItem(
                                label: 'ID PELANGGAN',
                                value: licenseState.customerId!,
                                allowCopy: true,
                                isMobile: true,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (licenseState.planId != null && licenseState.planId!.isNotEmpty)
                            Expanded(
                              child: _buildLicenseInfoItem(
                                label: 'PAKET / PLAN',
                                value: licenseState.planId!.toUpperCase(),
                                isMobile: true,
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (licenseState.maskedKey != null && licenseState.maskedKey!.isNotEmpty)
                            Expanded(
                              child: _buildLicenseInfoItem(
                                label: 'KODE LISENSI',
                                value: licenseState.maskedKey!,
                                allowCopy: true,
                                isMobile: true,
                              ),
                            ),
                        ],
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      if (licenseState.licenseId != null && licenseState.licenseId!.isNotEmpty)
                        _buildLicenseInfoItem(
                          label: 'ID LISENSI',
                          value: licenseState.licenseId!,
                          allowCopy: true,
                        ),
                      if (licenseState.customerId != null && licenseState.customerId!.isNotEmpty)
                        _buildLicenseInfoItem(
                          label: 'ID PELANGGAN',
                          value: licenseState.customerId!,
                          allowCopy: true,
                        ),
                      if (licenseState.planId != null && licenseState.planId!.isNotEmpty)
                        _buildLicenseInfoItem(
                          label: 'PAKET / PLAN',
                          value: licenseState.planId!.toUpperCase(),
                        ),
                      if (licenseState.maskedKey != null && licenseState.maskedKey!.isNotEmpty)
                        _buildLicenseInfoItem(
                          label: 'KODE LISENSI (MASKED)',
                          value: licenseState.maskedKey!,
                          allowCopy: true,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
        SizedBox(height: isMobile ? 12 : 16),
        const Divider(),
        SizedBox(height: isMobile ? 10 : 12),

        // Update License Input Form
        Text(
          'Perbarui License Key:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14),
        ),
        const SizedBox(height: 2),
        Text(
          isMobile
              ? 'Masukkan key baru untuk upgrade atau perpanjang lisensi.'
              : 'Masukkan License Key baru untuk upgrade paket atau memperpanjang masa aktif. Sistem akan langsung memperbarui lisensi tanpa perlu menghapus token lama.',
          style: TextStyle(fontSize: isMobile ? 11 : 12, color: Colors.grey.shade600),
        ),
        SizedBox(height: isMobile ? 8 : 12),
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _licenseKeyController,
                enabled: _isEditingUnlocked && !_isUpdatingLicense,
                decoration: InputDecoration(
                  labelText: 'License Key Baru',
                  hintText: 'Contoh: TOKO-XXXX-XXXX-XXXX',
                  prefixIcon: const Icon(Icons.vpn_key_rounded, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: (_isEditingUnlocked && !_isUpdatingLicense) ? _handleUpdateLicense : null,
                icon: _isUpdatingLicense
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Terapkan Lisensi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _licenseKeyController,
                  enabled: _isEditingUnlocked && !_isUpdatingLicense,
                  decoration: InputDecoration(
                    labelText: 'License Key Baru',
                    hintText: 'Contoh: TOKO-XXXX-XXXX-XXXX',
                    prefixIcon: const Icon(Icons.vpn_key_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: (_isEditingUnlocked && !_isUpdatingLicense) ? _handleUpdateLicense : null,
                icon: _isUpdatingLicense
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Terapkan Lisensi', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLicenseInfoItem({
    required String label,
    required String value,
    bool allowCopy = false,
    bool isMobile = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 9.5 : 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SelectableText(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 11.5 : 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (allowCopy) ...[
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label berhasil disalin ke clipboard!'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(Icons.copy_rounded, size: 13, color: Colors.blue),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }


  Future<void> _handleUpdateLicense() async {
    final key = _licenseKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masukkan License Key terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUpdatingLicense = true;
    });

    try {
      final success = await ref.read(licenseProvider.notifier).activate(key);
      if (!mounted) return;

      if (success) {
        _licenseKeyController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lisensi berhasil diperbarui! Seluruh fitur baru langsung aktif.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        final error = ref.read(licenseProvider).errorMessage ?? 'Gagal memperbarui lisensi';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLicense = false;
        });
      }
    }
  }

  Future<void> _handleRefreshLicense() async {
    setState(() {
      _isRefreshingLicense = true;
    });
    try {
      await ref.read(licenseProvider.notifier).refreshStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Status dan fitur lisensi berhasil disinkronkan.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal sinkronisasi lisensi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingLicense = false;
        });
      }
    }
  }

  Widget _buildDatabaseSettings() {
    final licenseState = ref.watch(licenseProvider);
    final features = licenseState.features;
    final bool hasAutoBackup = features['automatic_backup'] == true;
    final settings = ref.watch(settingsNotifierProvider);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return _buildCardSection(
      title: 'Sistem & Database',
      icon: Icons.storage_rounded,
      children: [
        Text(
          isMobile
              ? 'Amankan data transaksi Anda atau restore ke perangkat lain.'
              : 'Backup database untuk mengamankan data Anda atau memindahkan ke perangkat lain menggunakan Restore.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 11.5 : 13),
        ),
        SizedBox(height: isMobile ? 10 : 16),
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _handleBackup,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Manual Backup Database', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade700,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _handleRestore,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Manual Restore Database', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  foregroundColor: Colors.deepPurple.shade700,
                  side: BorderSide(color: Colors.deepPurple.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _handleBackup,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Manual Backup'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleRestore,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Manual Restore'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.deepPurple.shade700,
                    side: BorderSide(color: Colors.deepPurple.shade200),
                  ),
                ),
              ),
            ],
          ),
        SizedBox(height: isMobile ? 12 : 24),
        const Divider(),
        SizedBox(height: isMobile ? 10 : 16),
        Row(
          children: [
            Icon(Icons.cloud_sync_rounded, color: Colors.green, size: isMobile ? 18 : 22),
            const SizedBox(width: 8),
            Text(
              'Automatic Backup',
              style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.bold),
            ),
            if (!hasAutoBackup) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, size: 10, color: Colors.amber),
                    SizedBox(width: 2),
                    Text('PRO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          isMobile
              ? 'Backup otomatis berkala ke penyimpanan lokal sesuai jadwal.'
              : 'Biarkan sistem melakukan backup otomatis ke komputer Anda sesuai jadwal.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 11 : 12.5),
        ),
        SizedBox(height: isMobile ? 10 : 16),
        if (kIsWeb)
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: isMobile ? 18 : 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Fitur Auto-Backup tidak didukung di Web Browser. Gunakan aplikasi Desktop (Windows) untuk fitur ini.',
                    style: TextStyle(color: Colors.blue.shade800, fontSize: isMobile ? 11 : 13),
                  ),
                ),
              ],
            ),
          )
        else
          Opacity(
            opacity: hasAutoBackup ? 1.0 : 0.5,
            child: Column(
              children: [
                SwitchListTile(
                  dense: isMobile,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Aktifkan Auto-Backup',
                    style: TextStyle(fontSize: isMobile ? 13 : 15, fontWeight: FontWeight.w600),
                  ),
                  value: settings.autoBackupEnabled,
                  onChanged: hasAutoBackup
                      ? (val) {
                          ref.read(settingsNotifierProvider.notifier).updateSettings(
                            settings.copyWith(autoBackupEnabled: val),
                          );
                        }
                      : null,
                ),
                if (settings.autoBackupEnabled) ...[
                  SizedBox(height: isMobile ? 8 : 16),
                  DropdownButtonFormField<int>(
                    value: settings.autoBackupIntervalDays,
                    decoration: const InputDecoration(labelText: 'Interval (Hari)'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Tiap 1 Hari')),
                      DropdownMenuItem(value: 3, child: Text('Tiap 3 Hari')),
                      DropdownMenuItem(value: 7, child: Text('Tiap 7 Hari')),
                      DropdownMenuItem(value: 30, child: Text('Tiap 30 Hari')),
                    ],
                    onChanged: hasAutoBackup
                        ? (val) {
                            if (val != null) {
                              ref.read(settingsNotifierProvider.notifier).updateSettings(
                                settings.copyWith(autoBackupIntervalDays: val),
                              );
                            }
                          }
                        : null,
                  ),
                  SizedBox(height: isMobile ? 8 : 16),
                  InkWell(
                    onTap: hasAutoBackup
                        ? () async {
                            final String? selectedDirectory = await FilePicker.getDirectoryPath();
                            if (selectedDirectory != null) {
                              ref.read(settingsNotifierProvider.notifier).updateSettings(
                                settings.copyWith(autoBackupLocation: selectedDirectory),
                              );
                            }
                          }
                        : null,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: isMobile ? 10 : 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder_open, color: Colors.blue, size: isMobile ? 18 : 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Lokasi Penyimpanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 13)),
                                const SizedBox(height: 2),
                                Text(
                                  settings.autoBackupLocation.isEmpty 
                                    ? 'Belum diatur' 
                                    : settings.autoBackupLocation,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 11 : 11.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit, size: isMobile ? 16 : 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleBackup() async {
    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser?.role != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akses ditolak. Fitur ini hanya untuk level Admin.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final apiClient = ref.read(apiClientProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sedang mengunduh backup dari server...')));

      final backupBytes = await apiClient.getBackupBytes();
      final fileName = 'tokopintar_manual_${DateTime.now().millisecondsSinceEpoch}.db';

      final saved = await FileSaverHelper.saveFile(
        bytes: backupBytes,
        fileName: fileName,
        dialogTitle: 'Simpan Backup Database (.db)',
        allowedExtensions: ['db'],
      );

      if (saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup berhasil disimpan.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal melakukan backup: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleRestore() async {
    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser?.role != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akses ditolak. Fitur ini hanya untuk level Admin.'), backgroundColor: Colors.red),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Peringatan Restore'),
        content: const Text(
          'Melakukan restore akan menimpa seluruh data toko di server saat ini.\n\n'
          'Setelah restore berhasil:\n'
          '1. Server database di PC Utama akan otomatis dimatikan.\n'
          '2. Buka terminal PC Utama dan jalankan ulang server.\n\n'
          'Anda yakin ingin melanjutkan?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      List<PlatformFile> files;
      // On Android, use FileType.any so that custom .db extensions are never grayed out by Samsung/Google Files
      if (!kIsWeb && Platform.isAndroid) {
        files = await FilePicker.pickFiles(
          type: FileType.any,
        );
      } else {
        files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['db'],
        );
      }

      if (files.isEmpty) return;

      final pickedFile = files.first;

      // Validate file extension
      if (!pickedFile.name.toLowerCase().endsWith('.db')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Format file salah! Harap pilih file cadangan berekstensi .db'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sedang mengunggah dan merestore database ke server...')),
        );
      }

      final apiClient = ref.read(apiClientProvider);
      final bytes = await pickedFile.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal membaca data file database.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final message = await apiClient.restoreBackupBytes(bytes, pickedFile.name);

      if (!mounted) return;
      final isAndroid = !kIsWeb && Platform.isAndroid;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Restore Berhasil!'),
          content: Text(
            '$message\n\n'
            'Langkah Selanjutnya:\n'
            '1. Server TokoPintar di PC Utama telah dimatikan otomatis.\n'
            '2. Buka terminal server di PC Utama dan jalankan ulang server.\n'
            '3. Buka/Restart aplikasi TokoPintar di semua kasir.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                if (isAndroid) {
                  SystemNavigator.pop();
                } else {
                  exit(0);
                }
              },
              child: const Text('Tutup Aplikasi'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal restore: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildCardSection({
    required String title,
    required dynamic icon,
    required List<Widget> children,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Card(
      elevation: isMobile ? 0.5 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        side: isMobile ? BorderSide(color: Colors.grey.withValues(alpha: 0.15)) : BorderSide.none,
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon is IconData)
                  Container(
                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: Theme.of(context).colorScheme.primary,
                      size: isMobile ? 18 : 20,
                    ),
                  )
                else if (icon is Widget)
                  icon,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 14 : 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: _isEditingUnlocked,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

