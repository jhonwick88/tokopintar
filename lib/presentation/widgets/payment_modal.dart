import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/pos_provider.dart';
import 'transaction_success_dialog.dart';

class PaymentModal extends ConsumerStatefulWidget {
  const PaymentModal({super.key});

  @override
  ConsumerState<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends ConsumerState<PaymentModal> {
  String _selectedMethod = 'cash'; // cash, qris, bank, ewallet, split
  final TextEditingController _paidController = TextEditingController();
  double _customCashPaid = 0.0;
  
  // Split payments parameters
  double _splitCashPaid = 0.0;
  double _splitCardPaid = 0.0;
  final TextEditingController _splitCashController = TextEditingController();
  final TextEditingController _splitCardController = TextEditingController();

  // Transaction details bank references
  String _bankName = 'BCA';
  final TextEditingController _refController = TextEditingController();

  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final grandTotal = ref.read(posNotifierProvider).grandTotal;
    _paidController.text = grandTotal.toInt().toString();
    _customCashPaid = grandTotal;
    HardwareKeyboard.instance.addHandler(_handleLocalKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleLocalKeyEvent);
    _paidController.dispose();
    _splitCashController.dispose();
    _splitCardController.dispose();
    _refController.dispose();
    super.dispose();
  }

  bool _handleLocalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return true;
    } else if (key == LogicalKeyboardKey.f4) {
      if (!_isProcessing) {
        final grandTotal = ref.read(posNotifierProvider).grandTotal;
        _processPayment(grandTotal);
      }
      return true;
    }
    return false;
  }

  void _onKeyPress(String val) {
    if (_selectedMethod == 'split') return;
    
    final currentText = _paidController.text;
    if (val == '000' || val == '0000') {
      _paidController.text = currentText + val;
    } else {
      _paidController.text = currentText + val;
    }
    _updateCashPaid();
  }

  void _onBackspace() {
    final txt = _paidController.text;
    if (txt.isNotEmpty) {
      _paidController.text = txt.substring(0, txt.length - 1);
      _updateCashPaid();
    }
  }

  void _onClear() {
    _paidController.clear();
    setState(() {
      _customCashPaid = 0.0;
    });
  }

  void _updateCashPaid() {
    final parsed = double.tryParse(_paidController.text) ?? 0.0;
    setState(() {
      _customCashPaid = parsed;
    });
  }

  void _setExactAmount(double amt) {
    _paidController.text = amt.toInt().toString();
    setState(() {
      _customCashPaid = amt;
    });
  }

  void _addNominal(double nominal) {
    final current = double.tryParse(_paidController.text) ?? 0.0;
    final updated = current + nominal;
    _paidController.text = updated.toInt().toString();
    setState(() {
      _customCashPaid = updated;
    });
  }

  Future<void> _processPayment(double grandTotal) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    double paidAmount = _customCashPaid;
    if (_selectedMethod == 'qris' || _selectedMethod == 'bank' || _selectedMethod == 'ewallet') {
      paidAmount = grandTotal; // Exact payment
    } else if (_selectedMethod == 'split') {
      paidAmount = _splitCashPaid + _splitCardPaid;
      if (paidAmount < grandTotal) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Total pembayaran split harus memenuhi total belanja!';
        });
        return;
      }
    }

    if (paidAmount < grandTotal) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Uang bayar kurang!';
      });
      return;
    }

    try {
      final sale = await ref.read(posNotifierProvider.notifier).checkout(
            paymentMethod: _selectedMethod,
            paidAmount: paidAmount,
          );
      
      setState(() {
        _isProcessing = false;
      });

      if (mounted && sale != null) {
        final navigator = Navigator.of(context);
        navigator.pop(); // Close Payment Modal
        showDialog(
          context: navigator.context,
          barrierDismissible: false,
          builder: (context) => TransactionSuccessDialog(sale: sale),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Gagal menyimpan transaksi: $e';
      });
    }
  }





  @override
  Widget build(BuildContext context) {
    final posState = ref.watch(posNotifierProvider);
    final grandTotal = posState.grandTotal;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 800,
        height: 660,
        child: Row(
          children: [
            // Left pane: Payment Details & Selection
            Expanded(
              flex: 11,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Metode Pembayaran',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            
                            // Toggle Buttons
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildMethodTab('cash', Icons.money_rounded, 'Tunai'),
                                  const SizedBox(width: 8),
                                  _buildMethodTab('qris', Icons.qr_code_2_rounded, 'QRIS'),
                                  const SizedBox(width: 8),
                                  _buildMethodTab('bank', Icons.credit_card_rounded, 'Bank/Card'),
                                  const SizedBox(width: 8),
                                  _buildMethodTab('ewallet', Icons.wallet_rounded, 'E-Wallet'),
                                  const SizedBox(width: 8),
                                  _buildMethodTab('split', Icons.alt_route_rounded, 'Split'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Dynamic payment details screen based on selection
                            _buildSelectedMethodPane(grandTotal),
                            
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Subtotal:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(_formatRupiah(posState.subtotal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            if (posState.totalDiscount > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Diskon:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text('-${_formatRupiah(posState.totalDiscount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.red)),
                                ],
                              ),
                            ],
                            if (posState.enableServiceCharge && posState.serviceCharge > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Service Charge (${posState.serviceChargePercentage.toInt()}%):', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(_formatRupiah(posState.serviceCharge), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ],
                            if (posState.enableTax && posState.tax > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Pajak PPN (${posState.taxPercentage.toInt()}%):', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(_formatRupiah(posState.tax), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ],
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Harus Dibayar:', style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold)),
                                Text(
                                  _formatRupiah(grandTotal),
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (_errorMessage != null) ...[
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                    ],
                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Batal (ESC)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isProcessing ? null : () => _processPayment(grandTotal),
                            child: _isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Konfirmasi Pembayaran (F4)'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const VerticalDivider(width: 1),
            
            // Right Pane: Standard Touch Keypad (only for cash payments)
            if (_selectedMethod == 'cash')
              Container(
                width: 320,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Exact & nominal shortcuts
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () => _setExactAmount(grandTotal),
                          child: const Text('Uang Pas'),
                        ),
                        ElevatedButton(
                          onPressed: () => _addNominal(10000),
                          child: const Text('+10rb'),
                        ),
                        ElevatedButton(
                          onPressed: () => _addNominal(20000),
                          child: const Text('+20rb'),
                        ),
                        ElevatedButton(
                          onPressed: () => _addNominal(50000),
                          child: const Text('+50rb'),
                        ),
                        ElevatedButton(
                          onPressed: () => _addNominal(100000),
                          child: const Text('+100rb'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Table(
                        children: [
                          TableRow(
                            children: [
                              _buildPadBtn('1'),
                              _buildPadBtn('2'),
                              _buildPadBtn('3'),
                            ],
                          ),
                          TableRow(
                            children: [
                              _buildPadBtn('4'),
                              _buildPadBtn('5'),
                              _buildPadBtn('6'),
                            ],
                          ),
                          TableRow(
                            children: [
                              _buildPadBtn('7'),
                              _buildPadBtn('8'),
                              _buildPadBtn('9'),
                            ],
                          ),
                          TableRow(
                            children: [
                              _buildPadBtn('0'),
                              _buildPadBtn('000'),
                              IconButton(
                                onPressed: _onBackspace,
                                icon: const Icon(Icons.backspace_outlined),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _onClear,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodTab(String code, IconData icon, String label) {
    final active = _selectedMethod == code;
    return ChoiceChip(
      iconTheme: IconThemeData(color: active ? Colors.white : null),
      label: Text(label),
      avatar: Icon(icon),
      selected: active,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedMethod = code;
            _errorMessage = null;
          });
        }
      },
    );
  }

  Widget _buildSelectedMethodPane(double grandTotal) {
    switch (_selectedMethod) {
      case 'cash':
        final change = _customCashPaid - grandTotal;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jumlah Uang Tunai yang Diterima:', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: _paidController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onChanged: (val) {
                _updateCashPaid();
              },
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: change >= 0 ? Colors.green.withOpacity(0.08) : Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    change >= 0 ? 'Kembalian:' : 'Kurang Bayar:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: change >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  Text(
                    _formatRupiah(change.abs()),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: change >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        
      case 'qris':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Display dynamic QRIS Code
              QrImageView(
                data: 'https://qris.tokopintar.id/pay?invoice=DUMMY_POS_${DateTime.now().millisecondsSinceEpoch}&amount=${grandTotal.toInt()}',
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'QRIS DUMMY AKTIF',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'Scan QR di atas untuk menyelesaikan pembayaran',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        );
        
      case 'bank':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Bank/EDC:', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _bankName,
              items: ['BCA', 'Mandiri', 'BNI', 'BRI', 'CIMB Niaga'].map((b) {
                return DropdownMenuItem(value: b, child: Text(b));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _bankName = val);
              },
            ),
            const SizedBox(height: 16),
            const Text('Nomor Referensi Transaksi (Optional):', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: _refController,
              decoration: const InputDecoration(
                hintText: 'Masukkan no. struk EDC / referensi',
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        );
        
      case 'ewallet':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih E-Wallet:', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: 'GoPay',
              items: ['GoPay', 'OVO', 'Dana', 'LinkAja', 'ShopeePay'].map((e) {
                return DropdownMenuItem(value: e, child: Text(e));
              }).toList(),
              onChanged: (val) {},
            ),
            const SizedBox(height: 16),
            const Text('No. Handphone Pelanggan:', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            const TextField(
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '081xxxxxxxx',
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        );

      case 'split':
        final totalSplit = _splitCashPaid + _splitCardPaid;
        final splitDifference = grandTotal - totalSplit;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detail Pembayaran Kombinasi (Split):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Jumlah Tunai:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _splitCashController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(prefixText: 'Rp '),
                        onChanged: (val) {
                          setState(() {
                            _splitCashPaid = double.tryParse(val) ?? 0.0;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Jumlah Card/Debit:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _splitCardController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(prefixText: 'Rp '),
                        onChanged: (val) {
                          setState(() {
                            _splitCardPaid = double.tryParse(val) ?? 0.0;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: splitDifference <= 0 ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    splitDifference <= 0 ? 'Lunas / Kembalian:' : 'Belum Terbayar:',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: splitDifference <= 0 ? Colors.green : Colors.orange,
                    ),
                  ),
                  Text(
                    _formatRupiah(splitDifference.abs()),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: splitDifference <= 0 ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        
      default:
        return const SizedBox();
    }
  }

  Widget _buildPadBtn(String text) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _onKeyPress(text),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _formatRupiah(double val) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(val);
  }
}


