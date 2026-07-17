import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionsDialog extends StatefulWidget {
  const AppPermissionsDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const AppPermissionsDialog(),
    );
  }

  @override
  State<AppPermissionsDialog> createState() => _AppPermissionsDialogState();
}

class _AppPermissionsDialogState extends State<AppPermissionsDialog> {
  Map<Permission, PermissionStatus> _statuses = {};
  bool _isLoading = true;

  final List<PermissionItem> _permissionItems = [
    PermissionItem(
      permission: Permission.camera,
      name: 'Kamera',
      description: 'Digunakan untuk memindai barcode barang saat transaksi POS.',
      icon: Icons.camera_alt_rounded,
      color: Colors.blue,
    ),
    PermissionItem(
      permission: Permission.locationWhenInUse,
      name: 'Lokasi',
      description: 'Diperlukan untuk mendeteksi & menyambungkan printer thermal Bluetooth.',
      icon: Icons.location_on_rounded,
      color: Colors.green,
    ),
    PermissionItem(
      permission: Permission.microphone,
      name: 'Mikrofon',
      description: 'Diperlukan untuk pencarian suara produk dan catatan audio.',
      icon: Icons.mic_rounded,
      color: Colors.orange,
    ),
    PermissionItem(
      permission: Permission.bluetoothConnect, // Represents Nearby Devices / Bluetooth
      name: 'Device Sekitar',
      description: 'Diperlukan untuk menghubungkan printer Bluetooth di Android 12+.',
      icon: Icons.devices_other_rounded,
      color: Colors.purple,
      extraPermissions: [Permission.bluetoothScan],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
  }

  Future<void> _checkAllPermissions() async {
    setState(() => _isLoading = true);
    
    final Map<Permission, PermissionStatus> tempStatuses = {};
    
    // Check platform compatibility
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      // Mock granted for unsupported platforms like Desktop/Web for clean preview
      for (final item in _permissionItems) {
        tempStatuses[item.permission] = PermissionStatus.granted;
      }
    } else {
      for (final item in _permissionItems) {
        tempStatuses[item.permission] = await item.permission.status;
      }
    }

    if (mounted) {
      setState(() {
        _statuses = tempStatuses;
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPermission(PermissionItem item) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} otomatis aktif di platform ini.'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    final currentStatus = _statuses[item.permission];
    
    if (currentStatus == PermissionStatus.permanentlyDenied) {
      // Direct user to open App settings
      final opened = await openAppSettings();
      if (!opened) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal membuka pengaturan aplikasi. Silakan buka secara manual.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    // Request primary permission
    await item.permission.request();
    
    // Request extra permissions if any (e.g. bluetoothScan along with bluetoothConnect)
    if (item.extraPermissions != null) {
      for (final p in item.extraPermissions!) {
        await p.request();
      }
    }

    // Recheck statuses
    await _checkAllPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.security_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          const Text('Izin Aplikasi POS', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      content: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : Container(
              constraints: const BoxConstraints(maxWidth: 450),
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aktifkan izin berikut untuk memastikan semua fitur kasir dan printer berjalan dengan lancar.',
                    style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: _permissionItems.map((item) {
                          final status = _statuses[item.permission] ?? PermissionStatus.denied;
                          return _buildPermissionTile(item, status);
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildPermissionTile(PermissionItem item, PermissionStatus status) {
    String statusText = 'Belum Diizinkan';
    Color statusBg = Colors.orange.shade50;
    Color statusFg = Colors.orange.shade800;
    IconData actionIcon = Icons.arrow_forward_ios_rounded;
    String actionText = 'Izinkan';

    if (status == PermissionStatus.granted) {
      statusText = 'Aktif';
      statusBg = Colors.green.shade50;
      statusFg = Colors.green.shade800;
      actionIcon = Icons.check_circle_rounded;
      actionText = 'Aktif';
    } else if (status == PermissionStatus.permanentlyDenied) {
      statusText = 'Ditolak Permanen';
      statusBg = Colors.red.shade50;
      statusFg = Colors.red.shade800;
      actionIcon = Icons.settings_rounded;
      actionText = 'Pengaturan';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(width: 14),
          
          // Info Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    // const SizedBox(width: 8),
                    // Container(
                    //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    //   decoration: BoxDecoration(
                    //     color: statusBg,
                    //     borderRadius: BorderRadius.circular(12),
                    //   ),
                    //   child: Text(
                    //     statusText,
                    //     style: TextStyle(
                    //       fontSize: 10,
                    //       fontWeight: FontWeight.bold,
                    //       color: statusFg,
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Action Button
          status == PermissionStatus.granted
              ? Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 28)
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: status == PermissionStatus.permanentlyDenied 
                        ? Colors.red.shade50 
                        : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    foregroundColor: status == PermissionStatus.permanentlyDenied 
                        ? Colors.red.shade800 
                        : Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _requestPermission(item),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(actionText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Icon(actionIcon, size: 12),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

class PermissionItem {
  final Permission permission;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<Permission>? extraPermissions;

  PermissionItem({
    required this.permission,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.extraPermissions,
  });
}
