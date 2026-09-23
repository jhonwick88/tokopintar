import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/license_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/server_url_dialog.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _keyController = TextEditingController();

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _showServerUrlDialog() async {
    final settings = ref.read(settingsNotifierProvider);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ServerUrlDialog(
          initialUrl: settings.restApiUrl,
          onSave: (newUrl) async {
            if (newUrl.isNotEmpty) {
              final updated = settings.copyWith(restApiUrl: newUrl);
              await ref.read(settingsNotifierProvider.notifier).updateSettings(updated);
              await ref.read(licenseProvider.notifier).refreshStatus();
            }
          },
        );
      },
    );
  }

  Future<void> _activate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a license key.')),
      );
      return;
    }

    final success = await ref.read(licenseProvider.notifier).activate(key);
    if (!mounted) return;

    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 64),
              SizedBox(height: 16),
              Text('Aktivasi Berhasil!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Mengalihkan ke halaman Login...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );

      // REDIRECT TO LOGIN AFTER 2 SECONDS
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Dismiss dialog
          context.go('/login');
        }
      });
    } else {
      final error = ref.read(licenseProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Activation failed'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Ubah URL Server',
            textColor: Colors.white,
            onPressed: _showServerUrlDialog,
          ),
        ),
      );
    }
  }

  Future<void> _requestTrial() async {
    final success = await ref.read(licenseProvider.notifier).requestTrial();
    if (!mounted) return;

    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 64),
              SizedBox(height: 16),
              Text('Trial Diaktifkan!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Mengalihkan ke halaman Login...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );

      // REDIRECT TO LOGIN AFTER 2 SECONDS
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Dismiss dialog
          context.go('/login');
        }
      });
    } else {
      final error = ref.read(licenseProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Gagal mengambil trial'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Ubah URL Server',
            textColor: Colors.white,
            onPressed: _showServerUrlDialog,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(licenseProvider);
    final settings = ref.watch(settingsNotifierProvider);

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.security, size: 64, color: Colors.blueAccent),
                    const SizedBox(height: 24),
                    const Text(
                      'Activate TokoPintar POS',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your license key to continue.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _keyController,
                      decoration: const InputDecoration(
                        labelText: 'License Key',
                        hintText: 'e.g. PL-POS-PRO-XXXX',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.vpn_key),
                      ),
                      onSubmitted: (_) => _activate(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: state.isLoading ? null : _activate,
                        child: state.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Activate', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: state.isLoading ? null : _requestTrial,
                        child: const Text('Coba Gratis 14 Hari', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Display Current Server info
                    InkWell(
                      onTap: _showServerUrlDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.link, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Server: ${settings.restApiUrl}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (state.machineFingerprint != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'HWID: ${state.machineFingerprint}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
          // Top-right Server Configuration Button
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: Tooltip(
                  message: 'Konfigurasi URL Server Backend',
                  child: IconButton(
                    icon: Icon(
                      Icons.settings_ethernet,
                      size: 28,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    ),
                    onPressed: _showServerUrlDialog,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
