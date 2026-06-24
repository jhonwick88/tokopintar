import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/settings_model.dart';
import '../../domain/services/printer_service.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/main_layout.dart';

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

  String _printerType = 'LAN';
  bool _isEditingUnlocked = false;

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

    // Check if the current user is already an Admin to unlock editing
    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser?.role == 'admin') {
      _isEditingUnlocked = true;
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
    super.dispose();
  }

  void _requestAdminUnlock() {
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
              hintText: 'PIN default: 1234',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (pinController.text == '1234') {
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

  void _printTestPage() async {
    final builder = EscPosBuilder();
    builder.initialize();
    builder.alignCenter();
    builder.boldOn();
    builder.text('TEST PRINT RECEIPT');
    builder.text(_shopNameController.text);
    builder.boldOff();
    builder.text('Printer Type: $_printerType');
    builder.text('IP: ${_printerIpController.text}:${_printerPortController.text}');
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test print dihasilkan (${builder.bytes.length} bytes). Koneksi printer mock.'),
          backgroundColor: Colors.indigo,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      currentRoute: '/settings',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pengaturan Sistem', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  title: 'Koneksi REST API Backend',
                  icon: Icons.api_rounded,
                  children: [
                    _buildTextField(
                      controller: _apiUrlController,
                      label: 'Base URL API Golang',
                      hint: 'http://localhost:8080',
                      validator: (val) => val!.isEmpty ? 'URL REST API wajib diisi' : null,
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
                          child: DropdownButtonFormField<String>(
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
                                      });
                                    }
                                  }
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _printerPortController,
                            label: 'Port Printer (Default 9100)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_printerType == 'LAN')
                      _buildTextField(
                        controller: _printerIpController,
                        label: 'IP Address Printer LAN',
                        hint: '192.168.1.100',
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
                      onPressed: _printTestPage,
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: const Text('Cetak Halaman Uji'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isEditingUnlocked ? _saveSettings : null,
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan Konfigurasi'),
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
    required IconData icon,
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
                Icon(icon, color: Theme.of(context).colorScheme.primary),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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
