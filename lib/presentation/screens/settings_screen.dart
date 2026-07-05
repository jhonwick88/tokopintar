import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/settings_model.dart';
import '../../domain/services/printer_service.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/main_layout.dart';
import 'quick_add_item_settings_screen.dart';

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
  
  bool _enableTax = false;
  bool _enableServiceCharge = false;
  int _printerPaperSize = 58;
  int _printReceiptCopies = 1;
  bool _autoPrintOnCheckout = false;

  String _printerType = 'LAN';
  String _printerMacAddress = '';
  List<BluetoothInfo> _bluetoothDevices = [];
  bool _isScanningBluetooth = false;
  bool _isTestingPrinter = false;
  bool _isEditingUnlocked = false;
  bool _isTestingConnection = false;
  String? _connectionStatus;

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
    _enableTax = settings.enableTax;
    _enableServiceCharge = settings.enableServiceCharge;
    _printerPaperSize = settings.printerPaperSize;
    _printReceiptCopies = settings.printReceiptCopies;
    _autoPrintOnCheckout = settings.autoPrintOnCheckout;

    // Check if the current user is already an Admin to unlock editing
    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser?.role == 'admin') {
      _isEditingUnlocked = true;
    }

    if (_printerType == 'Bluetooth') {
      Future.delayed(Duration.zero, () {
        _scanBluetoothDevices();
      });
    }
  }

  Future<void> _scanBluetoothDevices() async {
    setState(() {
      _isScanningBluetooth = true;
    });
    try {
      final bool isGranted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Akses perangkat terdekat (Bluetooth) diperlukan untuk mendeteksi printer.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _isScanningBluetooth = false;
        });
        return;
      }

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

    final updated = SettingsModel(
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengaturan berhasil disimpan'), backgroundColor: Colors.green),
    );
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
      setState(() {
        _isTestingConnection = false;
      });
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
        text = 'Koneksi Berhasil! Terhubung ke server REST API Golang.';
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
                    color: Colors.green.withOpacity(0.15),
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
            padding: const EdgeInsets.all(24),
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
                            label: 'Base URL API Golang',
                            hint: 'http://localhost:8080',
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
                          label: const Text('Tes'),
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
                              value: _printerMacAddress.isEmpty ? null : _printerMacAddress,
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
              const SizedBox(height: 24),

                // Section 4: Aplikasi & Sistem
                _buildCardSection(
                  title: 'Aplikasi & Sistem',
                  icon: Icons.settings_display_rounded,
                  children: [
                    ListTile(
                      leading: Icon(themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
                      title: Text(themeMode == ThemeMode.dark ? 'Mode Gelap Aktif' : 'Mode Terang Aktif'),
                      trailing: Switch(
                        value: themeMode == ThemeMode.dark,
                        onChanged: (val) {
                          ref.read(themeModeProvider.notifier).state =
                              val ? ThemeMode.dark : ThemeMode.light;
                        },
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.bolt, color: Colors.amber),
                      title: const Text('Kelola Quick Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Konfigurasi tombol cepat untuk produk kasir'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const QuickAddItemSettingsScreen()),
                        );
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Keluar dari Akun (Logout)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Mengakhiri sesi kasir aktif saat ini'),
                      onTap: () => _confirmAndLogout(context),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Submit Buttons Row
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

  Widget _buildCardSection({
    required String title,
    required dynamic icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon is IconData)
                  Icon(icon, color: Theme.of(context).colorScheme.primary)
                else if (icon is Widget)
                  icon,
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
