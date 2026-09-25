import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/reconciliation_provider.dart';
import '../../data/models/cash_movement_model.dart';

class CashOutDialog extends ConsumerStatefulWidget {
  const CashOutDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const CashOutDialog(),
    );
  }

  @override
  ConsumerState<CashOutDialog> createState() => _CashOutDialogState();
}

class _CashOutDialogState extends ConsumerState<CashOutDialog> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _cashierController = TextEditingController();
  
  String _selectedCategory = 'Pengamen';
  final List<String> _categories = [
    'Pengamen',
    'Sumbangan',
    'Operasional',
    'Konsumsi',
    'Lain-lain',
  ];

  final List<double> _quickAmounts = [
    500,
    1000,
    2000,
    5000,
    10000,
    20000,
    50000,
  ];

  double _amount = 0.0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authNotifierProvider);
    _cashierController.text = auth.currentUser?.fullname.isNotEmpty == true
        ? auth.currentUser!.fullname
        : (auth.currentUser?.username ?? 'Kasir');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _cashierController.dispose();
    super.dispose();
  }

  void _selectQuickAmount(double value) {
    setState(() {
      _amount = value;
      _amountController.text = value.toStringAsFixed(0);
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    final amountVal = double.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
    if (amountVal <= 0) {
      setState(() {
        _errorMessage = 'Nominal kas keluar harus lebih dari Rp 0';
      });
      return;
    }

    final cashierName = _cashierController.text.trim();
    if (cashierName.isEmpty) {
      setState(() {
        _errorMessage = 'Nama kasir / operator wajib diisi';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final movement = CashMovementModel(
        id: '',
        date: DateTime.now(),
        cashierName: cashierName,
        type: 'OUT',
        category: _selectedCategory,
        amount: amountVal,
        notes: _notesController.text.trim(),
      );

      await ref.read(reconciliationProvider.notifier).addCashMovement(movement);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Kas keluar Rp ${NumberFormat("#,##0", "id_ID").format(amountVal)} ($_selectedCategory) berhasil dicatat',
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal menyimpan: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.output_rounded, color: Colors.orange.shade800, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Catat Kas Keluar',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Pengeluaran uang tunai dari laci kasir',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Error alert
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Kategori Choice Chips
                const Text(
                  'Kategori Pengeluaran',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: Theme.of(context).colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade800,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Quick Amount Chips
                const Text(
                  'Pilihan Nominal Cepat',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickAmounts.map((q) {
                    final isCurrent = _amount == q;
                    return ActionChip(
                      backgroundColor: isCurrent ? Colors.orange.shade100 : Colors.grey.shade100,
                      side: BorderSide(
                        color: isCurrent ? Colors.orange.shade400 : Colors.grey.shade300,
                      ),
                      label: Text(
                        currencyFormatter.format(q),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isCurrent ? Colors.orange.shade900 : Colors.grey.shade800,
                        ),
                      ),
                      onPressed: () => _selectQuickAmount(q),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Input Nominal Custom
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Nominal Kas Keluar (Rp) *',
                    hintText: 'Contoh: 500 atau 20000',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _amount = double.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
                      if (_errorMessage != null) _errorMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Catatan / Keperluan
                TextField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Keterangan / Keperluan (Opsional)',
                    hintText: 'Misal: Sumbangan mushola, pengamen keliling, beli plastik',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),

                // Nama Kasir
                TextField(
                  controller: _cashierController,
                  decoration: InputDecoration(
                    labelText: 'Nama Kasir / Operator *',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Batal'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isLoading ? 'Menyimpan...' : 'Simpan Kas Keluar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
