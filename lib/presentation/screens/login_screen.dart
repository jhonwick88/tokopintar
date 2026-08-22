import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../data/models/settings_model.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final List<String> _pin = [];
  final int _pinLength = 4;
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    super.dispose();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (_isDialogOpen) return false; // Let text field handle input
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      _onKeyPress('0');
      return true;
    } else if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      _onKeyPress('1');
      return true;
    } else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      _onKeyPress('2');
      return true;
    } else if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      _onKeyPress('3');
      return true;
    } else if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      _onKeyPress('4');
      return true;
    } else if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
      _onKeyPress('5');
      return true;
    } else if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
      _onKeyPress('6');
      return true;
    } else if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
      _onKeyPress('7');
      return true;
    } else if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
      _onKeyPress('8');
      return true;
    } else if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
      _onKeyPress('9');
      return true;
    } else if (key == LogicalKeyboardKey.backspace) {
      _onBackspace();
      return true;
    } else if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.delete) {
      _onClear();
      return true;
    }

    return false;
  }

  void _onKeyPress(String val) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin.add(val);
      });
      if (_pin.length == _pinLength) {
        _submitPIN();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin.removeLast();
      });
    }
  }

  void _onClear() {
    setState(() {
      _pin.clear();
    });
  }

  Future<void> _submitPIN() async {
    final enteredPin = _pin.join();
    final success = await ref.read(authNotifierProvider.notifier).login(enteredPin);
    if (!success) {
      _onClear();
    }
  }

  void _showServerUrlDialog(BuildContext context, SettingsModel settings, WidgetRef ref) async {
    setState(() => _isDialogOpen = true);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _ServerUrlDialog(
          initialUrl: settings.restApiUrl,
          onSave: (newUrl) async {
            if (newUrl.isNotEmpty) {
              final updated = settings.copyWith(restApiUrl: newUrl);
              await ref.read(settingsNotifierProvider.notifier).updateSettings(updated);
            }
          },
        );
      },
    );
    if (mounted) setState(() => _isDialogOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final settings = ref.watch(settingsNotifierProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Circles for premium depth
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.08),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: const SizedBox(),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Tooltip(
              message: 'Konfigurasi Darurat (Ubah URL Server)',
              child: IconButton(
                icon: Icon(Icons.settings_ethernet, size: 28, color: Theme.of(context).colorScheme.primary.withOpacity(0.6)),
                onPressed: () => _showServerUrlDialog(context, settings, ref),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Container(
                width: 390,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    )
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Shop Logo Icon with sleek glass circle
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Header text
                    Text(
                      settings.shopName.isNotEmpty ? settings.shopName : 'Toko Pintar POS',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Masukkan PIN Kasir Anda',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 28),
                    
                    // PIN Dots indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pinLength, (index) {
                        final filled = index < _pin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                            border: Border.all(
                              color: filled
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                        );
                      }),
                    ),
                    
                    const SizedBox(height: 12),
                    // Loading and Error Messages
                    if (authState.isLoading)
                      const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else if (authState.errorMessage != null)
                      Text(
                        authState.errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                      )
                    else
                      const SizedBox(height: 24),
                    
                    const SizedBox(height: 12),
                    // Keypad
                    _buildKeypad(),
                    const SizedBox(height: 20),
                    
                    // Quick guide hints for testing
                    Divider(color: Colors.grey.withOpacity(0.15)),
                    const SizedBox(height: 12),
                    Text(
                      'Demo Admin PIN: 1234  |  Kasir PIN: 0000',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Table(
      children: [
        TableRow(
          children: [
            _buildKeypadButton('1'),
            _buildKeypadButton('2'),
            _buildKeypadButton('3'),
          ],
        ),
        TableRow(
          children: [
            _buildKeypadButton('4'),
            _buildKeypadButton('5'),
            _buildKeypadButton('6'),
          ],
        ),
        TableRow(
          children: [
            _buildKeypadButton('7'),
            _buildKeypadButton('8'),
            _buildKeypadButton('9'),
          ],
        ),
        TableRow(
          children: [
            _buildKeypadIconButton(Icons.clear, _onClear, tooltip: 'Hapus Semua'),
            _buildKeypadButton('0'),
            _buildKeypadIconButton(Icons.backspace_outlined, _onBackspace, tooltip: 'Hapus Satu'),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String label) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Center(
        child: InkWell(
          onTap: () => _onKeyPress(label),
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.03),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.07),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadIconButton(IconData icon, VoidCallback onPressed, {required String tooltip}) {
    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Center(
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 24,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServerUrlDialog extends StatefulWidget {
  final String initialUrl;
  final Future<void> Function(String) onSave;

  const _ServerUrlDialog({required this.initialUrl, required this.onSave});

  @override
  State<_ServerUrlDialog> createState() => _ServerUrlDialogState();
}

class _ServerUrlDialogState extends State<_ServerUrlDialog> {
  late TextEditingController _controller;
  bool _isTesting = false;
  bool _isSaving = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _controller.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = false;
    });

    try {
      final dio = Dio(BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
      ));
      final response = await dio.get('/api/company');
      setState(() {
        _testSuccess = response.statusCode == 200;
        _testResult = _testSuccess ? 'Koneksi Berhasil!' : 'Koneksi gagal (Status: ${response.statusCode})';
      });
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = 'Gagal terhubung ke server.';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 10),
          Text('Pengaturan Darurat'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Gunakan menu ini jika Anda tidak bisa login karena aplikasi terhubung ke IP/URL Server yang salah.'),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'URL Server API',
                hintText: 'http://192.168.x.x:8080',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting || _isSaving ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_find),
                    label: const Text('Tes Koneksi'),
                  ),
                ),
              ],
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testSuccess ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testSuccess ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _testSuccess ? Icons.check_circle : Icons.error,
                      color: _testSuccess ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          color: _testSuccess ? Colors.green[700] : Colors.red[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isTesting || _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isTesting || _isSaving
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  await widget.onSave(_controller.text.trim());
                  if (context.mounted) Navigator.pop(context);
                },
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Simpan URL'),
        ),
      ],
    );
  }
}
