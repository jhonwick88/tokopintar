import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class ServerUrlDialog extends StatefulWidget {
  final String initialUrl;
  final Future<void> Function(String) onSave;

  const ServerUrlDialog({
    super.key,
    required this.initialUrl,
    required this.onSave,
  });

  @override
  State<ServerUrlDialog> createState() => _ServerUrlDialogState();
}

class _ServerUrlDialogState extends State<ServerUrlDialog> {
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
        _testResult = 'Gagal terhubung ke server. Pastikan IP & Port benar serta server berjalan.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.settings_ethernet, color: Colors.blueAccent),
          SizedBox(width: 10),
          Text('Pengaturan URL Server'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Masukkan IP dan Port komputer server backend toko (rest_go_toko) yang berada di jaringan yang sama.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'URL Server API',
                hintText: 'http://192.168.1.100:8181',
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
                  color: _testSuccess ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testSuccess ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
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
