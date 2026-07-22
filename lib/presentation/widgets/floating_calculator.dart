import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

class FloatingCalculatorService {
  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context) {
    if (_overlayEntry != null) return;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => const _FloatingCalculatorWidget(),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _FloatingCalculatorWidget extends StatefulWidget {
  const _FloatingCalculatorWidget();

  @override
  State<_FloatingCalculatorWidget> createState() => _FloatingCalculatorWidgetState();
}

class _FloatingCalculatorWidgetState extends State<_FloatingCalculatorWidget> {
  double _top = 100;
  double _left = 0; 
  
  bool _isExpanded = false;
  bool _isInit = false;
  
  String _expression = '';
  String _result = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final size = MediaQuery.of(context).size;
      _left = size.width - 80;
      _top = size.height / 2 - 40;
      _isInit = true;
    }
  }

  void _onButtonPressed(String text) {
    setState(() {
      if (text == 'AC') {
        _expression = '';
        _result = '';
      } else if (text == '=') {
        _calculateResult();
      } else if (text == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else {
        _expression += text;
        // Auto calculate on every input for better UX (optional, but requested by modern calcs)
        // _calculateResult(); 
      }
    });
  }

  void _calculateResult() {
    if (_expression.isEmpty) return;
    try {
      Parser p = Parser();
      // Format string untuk parser
      String expStr = _expression
          .replaceAll('x', '*')
          .replaceAll('÷', '/')
          .replaceAll('%', '*(1/100)');
          
      Expression exp = p.parse(expStr);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      
      if (eval == eval.toInt()) {
        _result = eval.toInt().toString();
      } else {
        _result = eval.toStringAsFixed(2);
      }
    } catch (e) {
      _result = 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;
    
    return Positioned(
      top: _top,
      left: _left,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _top += details.delta.dy;
            _left += details.delta.dx;
            
            // Batas layar agar tidak keluar
            final calcWidth = _isExpanded ? (isDesktop ? 320.0 : size.width * 0.85) : 60.0;
            final calcHeight = _isExpanded ? 460.0 : 60.0; // Perkiraan tinggi
            
            if (_left < 0) _left = 0;
            if (_top < 0) _top = 0;
            if (_left > size.width - calcWidth) _left = size.width - calcWidth;
            if (_top > size.height - calcHeight) _top = size.height - calcHeight;
          });
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: _isExpanded ? _buildExpandedCalculator(isDesktop) : _buildCollapsedIcon(),
        ),
      ),
    );
  }

  Widget _buildCollapsedIcon() {
    return Material(
      key: const ValueKey('collapsed'),
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _isExpanded = true),
        customBorder: const CircleBorder(),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.calculate, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _buildExpandedCalculator(bool isDesktop) {
    final calcWidth = isDesktop ? 320.0 : MediaQuery.of(context).size.width * 0.85;
    return Material(
      key: const ValueKey('expanded'),
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: calcWidth,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Drag Handle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.drag_indicator, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Kalkulator Harga',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() => _isExpanded = false),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                // Display Layar
                Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.bottomRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _expression.isEmpty ? '0' : _expression,
                        style: const TextStyle(fontSize: 24, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _result.isEmpty ? '0' : _result,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Grid Tombol
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _calcButton('AC', color: Colors.red.shade400),
                      _calcButton('⌫', color: Colors.orange.shade400),
                      _calcButton('%', color: Theme.of(context).colorScheme.secondary),
                      _calcButton('÷', color: Theme.of(context).colorScheme.secondary),
                      
                      _calcButton('7'), _calcButton('8'), _calcButton('9'),
                      _calcButton('x', color: Theme.of(context).colorScheme.secondary),
                      
                      _calcButton('4'), _calcButton('5'), _calcButton('6'),
                      _calcButton('-', color: Theme.of(context).colorScheme.secondary),
                      
                      _calcButton('1'), _calcButton('2'), _calcButton('3'),
                      _calcButton('+', color: Theme.of(context).colorScheme.secondary),
                      
                      _calcButton('00'), _calcButton('0'), _calcButton('.'),
                      _calcButton('=', color: Theme.of(context).colorScheme.primary, isSolid: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _calcButton(String text, {Color? color, bool isSolid = false}) {
    return InkWell(
      onTap: () => _onButtonPressed(text),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isSolid ? color : (color?.withOpacity(0.1) ?? Colors.transparent),
          borderRadius: BorderRadius.circular(16),
          border: isSolid ? null : Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isSolid ? Colors.white : (color ?? Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}
