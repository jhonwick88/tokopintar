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
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Add to raw barcode listeners
    BarcodeService.instance.addBarcodeListener(widget.onBarcodeScanned);
  }

  @override
  void dispose() {
    BarcodeService.instance.removeBarcodeListener(widget.onBarcodeScanned);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastKeyEventTime).inMilliseconds;
    _lastKeyEventTime = now;

    // A hardware scanner typed character interval is typically < 50ms.
    // If the time between keypresses is too long (e.g. > 100ms), it's probably human typing.
    // We clear the buffer if it is human typing, unless the buffer is empty.
    if (elapsed > 100 && _buffer.isNotEmpty) {
      _buffer.clear();
    }

    final logicalKey = event.logicalKey;

    if (logicalKey == LogicalKeyboardKey.enter) {
      if (_buffer.isNotEmpty) {
        final barcode = _buffer.toString().trim();
        _buffer.clear();
        if (barcode.length >= 3) {
          widget.onBarcodeScanned(barcode);
        }
      }
    } else {
      // Intercept numeric and alphabetic characters
      final char = event.character;
      if (char != null && char.isNotEmpty) {
        _buffer.write(char);
      } else if (logicalKey.keyLabel.isNotEmpty && logicalKey.keyLabel.length == 1) {
        _buffer.write(logicalKey.keyLabel);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}
