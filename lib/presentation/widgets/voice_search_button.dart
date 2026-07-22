import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceSearchButton extends StatefulWidget {
  final Function(String) onResult;

  const VoiceSearchButton({super.key, required this.onResult});

  @override
  State<VoiceSearchButton> createState() => _VoiceSearchButtonState();
}

class _VoiceSearchButtonState extends State<VoiceSearchButton> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  final ValueNotifier<String> _textNotifier = ValueNotifier<String>('');
  
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _textNotifier.dispose();
    super.dispose();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            _stopAndReturn();
          }
        },
        onError: (val) {
          _stopAndReturn();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error rekaman suara: ${val.errorMsg}')),
          );
        },
      );
      
      if (available) {
        setState(() => _isListening = true);
        _textNotifier.value = '';
        _speech.listen(
          onResult: (val) {
            _textNotifier.value = val.recognizedWords;
          },
        );
        _showListeningDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin mikrofon ditolak atau tidak tersedia.')),
        );
      }
    }
  }
  
  void _stopAndReturn() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      if (_textNotifier.value.isNotEmpty) {
        widget.onResult(_textNotifier.value);
      }
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  void _showListeningDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mendengarkan...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_animationController.value * 0.15),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                          ),
                          child: Icon(
                            Icons.mic,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  ValueListenableBuilder<String>(
                    valueListenable: _textNotifier,
                    builder: (context, text, child) {
                      return Text(
                        text.isEmpty ? 'Silakan ucapkan nama produk...' : '"$text"',
                        style: const TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _stopAndReturn,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Batal / Berhenti'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
       // When dialog is dismissed by tapping outside
       if (_isListening) {
          _speech.stop();
          setState(() => _isListening = false);
          // Return result if there's any
          if (_textNotifier.value.isNotEmpty) {
            widget.onResult(_textNotifier.value);
          }
       }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.mic),
      onPressed: _listen,
      tooltip: 'Pencarian Suara',
      color: _isListening ? Theme.of(context).colorScheme.primary : null,
    );
  }
}
