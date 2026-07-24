import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CameraScannerDialog extends StatefulWidget {
  const CameraScannerDialog({super.key});

  @override
  State<CameraScannerDialog> createState() => _CameraScannerDialogState();
}

class _CameraScannerDialogState extends State<CameraScannerDialog> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _manualController = TextEditingController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: isSmallScreen ? const EdgeInsets.all(16) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      elevation: 0,
      child: Container(
        width: isSmallScreen ? double.infinity : 450,
        height: isSmallScreen ? size.height * 0.8 : 650,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            children: [
              // Scanner Area (Borderless at top)
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
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
                    // Custom Scanner Overlay
                    CustomPaint(
                      painter: _ScannerOverlayPainter(
                        animation: _animationController,
                        borderColor: colorScheme.primary,
                      ),
                    ),
                    // Close Button
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                    // Flash Toggle
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, state, child) {
                            switch (state.torchState) {
                              case TorchState.off:
                                return IconButton(
                                  icon: const Icon(Icons.flash_off, color: Colors.white),
                                  onPressed: () => _controller.toggleTorch(),
                                );
                              case TorchState.on:
                                return IconButton(
                                  icon: const Icon(Icons.flash_on, color: Colors.amber),
                                  onPressed: () => _controller.toggleTorch(),
                                );
                              default:
                                return const IconButton(
                                  icon: Icon(Icons.flash_off, color: Colors.grey),
                                  onPressed: null, // Disabled
                                );
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom Input Area
              Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Scan Barcode Produk',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Arahkan kamera ke barcode produk,\natau masukkan UPC secara manual',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Input Box
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _manualController,
                            autofocus: true,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Masukkan Barcode',
                              hintStyle: TextStyle(
                                letterSpacing: 0,
                                fontWeight: FontWeight.normal,
                                color: colorScheme.onSurface.withOpacity(0.4),
                              ),
                              prefixIcon: const Icon(Icons.keyboard),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                            onSubmitted: (val) {
                              if (val.trim().isNotEmpty) {
                                Navigator.of(context).pop(val.trim());
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                            padding: const EdgeInsets.all(16),
                            onPressed: () {
                              final val = _manualController.text.trim();
                              if (val.isNotEmpty) {
                                Navigator.of(context).pop(val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Animation<double> animation;
  final Color borderColor;

  _ScannerOverlayPainter({required this.animation, required this.borderColor}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final width = size.width * 0.75;
    final height = 150.0;
    final left = (size.width - width) / 2;
    final top = (size.height - height) / 2;

    final rect = Rect.fromLTWH(left, top, width, height);

    // Dimmed background
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.65);
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(backgroundPath, backgroundPaint);

    // Draw corners
    const cornerLength = 30.0;
    const radius = 16.0;

    // Top Left
    canvas.drawPath(
      Path()
        ..moveTo(left, top + cornerLength)
        ..lineTo(left, top + radius)
        ..arcToPoint(Offset(left + radius, top), radius: const Radius.circular(radius))
        ..lineTo(left + cornerLength, top),
      paint,
    );

    // Top Right
    canvas.drawPath(
      Path()
        ..moveTo(left + width - cornerLength, top)
        ..lineTo(left + width - radius, top)
        ..arcToPoint(Offset(left + width, top + radius), radius: const Radius.circular(radius))
        ..lineTo(left + width, top + cornerLength),
      paint,
    );

    // Bottom Left
    canvas.drawPath(
      Path()
        ..moveTo(left, top + height - cornerLength)
        ..lineTo(left, top + height - radius)
        ..arcToPoint(Offset(left + radius, top + height), radius: const Radius.circular(radius), clockwise: false)
        ..lineTo(left + cornerLength, top + height),
      paint,
    );

    // Bottom Right
    canvas.drawPath(
      Path()
        ..moveTo(left + width - cornerLength, top + height)
        ..lineTo(left + width - radius, top + height)
        ..arcToPoint(Offset(left + width, top + height - radius), radius: const Radius.circular(radius), clockwise: false)
        ..lineTo(left + width, top + height - cornerLength),
      paint,
    );

    // Scanning line
    final lineY = top + (height * animation.value);
    final linePaint = Paint()
      ..color = borderColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(left + 10, lineY),
      Offset(left + width - 10, lineY),
      linePaint,
    );
    
    // Line glow
    final glowPaint = Paint()
      ..color = borderColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      
    canvas.drawLine(
      Offset(left + 10, lineY),
      Offset(left + width - 10, lineY),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) => true;
}
