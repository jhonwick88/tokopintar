import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CameraScannerDialog extends StatefulWidget {
  const CameraScannerDialog({super.key});

  @override
  State<CameraScannerDialog> createState() => _CameraScannerDialogState();
}

class _CameraScannerDialogState extends State<CameraScannerDialog> {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _manualController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 450,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scan Barcode Produk',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: (capture) {
                          final List<Barcode> barcodes = capture.barcodes;
                          if (barcodes.isNotEmpty) {
                            final barcodeVal = barcodes.first.rawValue;
                            if (barcodeVal != null && barcodeVal.isNotEmpty) {
                              Navigator.of(context).pop(barcodeVal);
                            }
                          }
                        },
                      ),
                      // Scanner Overlay Overlay
                      Center(
                        child: Container(
                          width: 250,
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Arahkan kamera ke barcode produk, atau masukkan UPC secara manual:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualController,
                    decoration: const InputDecoration(
                      hintText: 'Masukkan UPC / Barcode',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        Navigator.of(context).pop(val.trim());
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final val = _manualController.text.trim();
                    if (val.isNotEmpty) {
                      Navigator.of(context).pop(val);
                    }
                  },
                  child: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
