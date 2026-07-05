import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final List<String> _pin = [];
  final int _pinLength = 4;

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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.08),
              Theme.of(context).colorScheme.secondary.withOpacity(0.05),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Container(
                width: 380,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Shop Logo Icon
                    Icon(
                      Icons.storefront_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    // Header text
                    const Text(
                      'Toko Pintar POS',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Masukkan PIN Kasir Anda',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // PIN Dots indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pinLength, (index) {
                        final filled = index < _pin.length;
                        return Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
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
                    
                    const SizedBox(height: 16),
                    // Loading and Error Messages
                    if (authState.isLoading)
                      const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (authState.errorMessage != null)
                      Text(
                        authState.errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                      )
                    else
                      const SizedBox(height: 24),
                    
                    const SizedBox(height: 16),
                    // Keypad
                    _buildKeypad(),
                    const SizedBox(height: 20),
                    
                    // Quick guide hints for testing
                    Divider(color: Colors.grey.withOpacity(0.2)),
                    const SizedBox(height: 10),
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
        ),
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
      padding: const EdgeInsets.all(8.0),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
          ),
        ),
        onPressed: () => _onKeyPress(label),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadIconButton(IconData icon, VoidCallback onPressed, {required String tooltip}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: IconButton(
        tooltip: tooltip,
        style: IconButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
      ),
    );
  }
}
