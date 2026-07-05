import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class BarcodeService {
  // Simple singleton pattern or service provider helper
  static final BarcodeService instance = BarcodeService._internal();
  BarcodeService._internal();

  final List<void Function(String)> _listeners = [];

  void addBarcodeListener(void Function(String) onBarcodeScanned) {
    _listeners.add(onBarcodeScanned);
  }

  void removeBarcodeListener(void Function(String) onBarcodeScanned) {
    _listeners.remove(onBarcodeScanned);
  }

  void notifyBarcodeScanned(String barcode) {
    for (var listener in _listeners) {
      listener(barcode);
    }
  }
}

/// A widget that listens to raw keyboard inputs globally and interprets them as a barcode.
/// USB and Bluetooth barcode scanners mimic a keyboard, typing the UPC digits in quick succession
/// and sending an 'Enter' key at the end.
class BarcodeKeyboardListener extends StatefulWidget {
  final Widget child;
  final void Function(String) onBarcodeScanned;

  const BarcodeKeyboardListener({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
  });

  @override
  State<BarcodeKeyboardListener> createState() => _BarcodeKeyboardListenerState();
}

class _BarcodeKeyboardListenerState extends State<BarcodeKeyboardListener> {
  final StringBuffer _buffer = StringBuffer();
  DateTime _lastKeyEventTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    BarcodeService.instance.addBarcodeListener(widget.onBarcodeScanned);
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
  }

  @override
  void dispose() {
    BarcodeService.instance.removeBarcodeListener(widget.onBarcodeScanned);
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    super.dispose();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final now = DateTime.now();
    final elapsed = now.difference(_lastKeyEventTime).inMilliseconds;
    _lastKeyEventTime = now;

    // A hardware scanner typed character interval is typically < 50ms.
    // If the time between keypresses is too long (e.g. > 100ms), it's probably human typing.
    // We clear the buffer if it is human typing, unless the buffer is empty.
    if (elapsed > 80 && _buffer.isNotEmpty) {
      _buffer.clear();
    }

    final logicalKey = event.logicalKey;

    if (logicalKey == LogicalKeyboardKey.enter) {
      if (_buffer.isNotEmpty) {
        final barcode = _buffer.toString().trim();
        _buffer.clear();
        if (barcode.length >= 3) {
          widget.onBarcodeScanned(barcode);
          return true; // Consume Enter key so it doesn't submit other focused text fields
        }
      }
    } else {
      // Intercept numeric and alphanumeric characters
      final char = event.character;
      if (char != null && char.isNotEmpty && RegExp(r'^[a-zA-Z0-9]$').hasMatch(char)) {
        _buffer.write(char);
        // If keys are typed extremely fast, it is definitely a barcode scanner.
        // Consume the key event so it doesn't get typed into focused inputs.
        if (elapsed < 35) {
          return true; 
        }
      } else if (logicalKey.keyLabel.isNotEmpty && logicalKey.keyLabel.length == 1 && RegExp(r'^[a-zA-Z0-9]$').hasMatch(logicalKey.keyLabel)) {
        _buffer.write(logicalKey.keyLabel);
        if (elapsed < 35) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
