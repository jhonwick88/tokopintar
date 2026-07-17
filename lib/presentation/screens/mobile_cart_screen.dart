import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/settings_provider.dart';
import '../../data/models/sale_model.dart';
import '../../domain/services/printer_service.dart';
import '../widgets/transaction_success_dialog.dart';
import 'pos_screen.dart';

class MobileCartScreen extends ConsumerStatefulWidget {
  const MobileCartScreen({super.key});

  @override
  ConsumerState<MobileCartScreen> createState() => _MobileCartScreenState();
}

class _MobileCartScreenState extends ConsumerState<MobileCartScreen> {
  final TextEditingController _cashController = TextEditingController();
  double _cashPaid = 0.0;
  String _selectedMethod = 'cash'; // cash, qris, bank, ewallet
  bool _isProcessing = false;
  String? _errorMessage;
  bool _isPaymentSectionExpanded = false;

  @override
  void initState() {
    super.initState();
    final grandTotal = ref.read(posNotifierProvider).grandTotal;
    _cashController.text = grandTotal.toInt().toString();
    _cashPaid = grandTotal;
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _updateCashPaid(String val) {
    final parsed = double.tryParse(val) ?? 0.0;
    setState(() {
      _cashPaid = parsed;
      _errorMessage = null;
    });
  }

  void _setExactAmount(double amt) {
    _cashController.text = amt.toInt().toString();
    setState(() {
      _cashPaid = amt;
      _errorMessage = null;
    });
  }

  void _addNominal(double nominal) {
    final current = double.tryParse(_cashController.text) ?? 0.0;
    final updated = current + nominal;
    _cashController.text = updated.toInt().toString();
    setState(() {
      _cashPaid = updated;
      _errorMessage = null;
    });
  }

  Future<void> _processCheckout(double grandTotal) async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    double paidAmount = _cashPaid;
    if (_selectedMethod != 'cash') {
      paidAmount = grandTotal; // Exact payment
    }

    if (paidAmount < grandTotal) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Uang bayar kurang dari total belanja!';
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
        navigator.pop(); // Go back to POS catalog
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



  Widget _buildSummaryRow(String label, String val, {Color? valueColor, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(
          val,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  void _openItemNoteAndDiscountDialog(CartItem cartItem) {
    final posNotifier = ref.read(posNotifierProvider.notifier);
    final noteController = TextEditingController(text: cartItem.note);
    final discController = TextEditingController(text: cartItem.discount.toInt().toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(cartItem.item.itemName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Catatan Item',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: discController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Diskon Item (Nominal Rp)',
                  prefixText: 'Rp ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final note = noteController.text;
                final discount = double.tryParse(discController.text) ?? 0.0;
                posNotifier.updateNote(cartItem.item.itemNo, note);
                posNotifier.applyItemDiscount(cartItem.item.itemNo, discount);
                Navigator.of(context).pop();
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _openHoldDialog() {
    final posState = ref.read(posNotifierProvider);
    if (posState.cartItems.isEmpty) return;

    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tahan Transaksi (Hold)'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Nama Penanda (meja, antrian, pelanggan)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(posNotifierProvider.notifier).holdTransaction(controller.text);
                Navigator.of(context).pop(); // Dismiss dialog
                Navigator.of(context).pop(); // Pop MobileCartScreen since cart is cleared
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaksi berhasil ditahan'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _openDiscountDialog() {
    final posNotifier = ref.read(posNotifierProvider.notifier);
    final posState = ref.read(posNotifierProvider);
    final valueController = TextEditingController(text: posState.discountValue.toInt().toString());
    String tempType = posState.discountType == 'none' ? 'nominal' : posState.discountType;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Diskon Transaksi'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Nominal (Rp)'),
                          selected: tempType == 'nominal',
                          onSelected: (val) {
                            if (val) setModalState(() => tempType = 'nominal');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Persen (%)'),
                          selected: tempType == 'percent',
                          onSelected: (val) {
                            if (val) setModalState(() => tempType = 'percent');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: valueController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: tempType == 'nominal' ? 'Masukkan Rupiah' : 'Masukkan Persen',
                      prefixText: tempType == 'nominal' ? 'Rp ' : null,
                      suffixText: tempType == 'percent' ? '%' : null,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    posNotifier.applyTransactionDiscount('none', 0.0);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Hapus Diskon', style: TextStyle(color: Colors.red)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final val = double.tryParse(valueController.text) ?? 0.0;
                    posNotifier.applyTransactionDiscount(tempType, val);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Terapkan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final posState = ref.watch(posNotifierProvider);
    final grandTotal = posState.grandTotal;
    final change = _cashPaid - grandTotal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang Belanja', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            onPressed: () {
              if (posState.cartItems.isEmpty) return;
              ref.read(posNotifierProvider.notifier).clearCart();
              Navigator.of(context).pop();
            },
            tooltip: 'Kosongkan Keranjang',
          ),
        ],
      ),
      body: posState.cartItems.isEmpty
          ? const Center(child: Text('Keranjang Belanja Kosong'))
          : Column(
              children: [
                // 1. List Cart Items (Vertical list, 1 card per row, no images)
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: posState.cartItems.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final cartItem = posState.cartItems[index];
                      return Dismissible(
                        key: Key('mobile-cart-${cartItem.item.itemNo}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          ref.read(posNotifierProvider.notifier).removeFromCart(cartItem.item.itemNo);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${cartItem.item.itemName} dihapus dari keranjang'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cartItem.item.itemName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatRupiah(cartItem.price),
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.primary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (cartItem.discount > 0)
                                            Text(
                                              'Disc: -${_formatRupiah(cartItem.discount)}',
                                              style: const TextStyle(color: Colors.red, fontSize: 11),
                                            ),
                                          if (cartItem.note.isNotEmpty)
                                            Text(
                                              '* Note: ${cartItem.note}',
                                              style: const TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_note),
                                      onPressed: () => _openItemNoteAndDiscountDialog(cartItem),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Sub: ${_formatRupiah(cartItem.subtotal)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 24),
                                          onPressed: () {
                                            ref.read(posNotifierProvider.notifier).updateQty(
                                                  cartItem.item.itemNo,
                                                  cartItem.qty - 1,
                                                );
                                          },
                                        ),
                                        InkWell(
                                          onTap: () => _showEditQtyDialog(cartItem),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${cartItem.qty}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 24),
                                          onPressed: () {
                                            ref.read(posNotifierProvider.notifier).updateQty(
                                                  cartItem.item.itemNo,
                                                  cartItem.qty + 1,
                                                );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // 2. Billing & Checkout Panel
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      )
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Swipe/Tap Trigger for expanding payment details
                          GestureDetector(
                            onVerticalDragEnd: (details) {
                              if (details.primaryVelocity != null) {
                                if (details.primaryVelocity! < 0) {
                                  // Swipe Up
                                  setState(() => _isPaymentSectionExpanded = true);
                                } else if (details.primaryVelocity! > 0) {
                                  // Swipe Down
                                  setState(() => _isPaymentSectionExpanded = false);
                                }
                              }
                            },
                            onTap: () {
                              setState(() => _isPaymentSectionExpanded = !_isPaymentSectionExpanded);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 1. Drag Handle with Indicator Icon
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isPaymentSectionExpanded
                                            ? Icons.keyboard_arrow_down
                                            : Icons.keyboard_arrow_up,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                      Container(
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.35),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                          
                          // 2. Scrollable Content (Billing details + Payment details)
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total Barang:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      Text(
                                        '${posState.cartItems.length} Jenis (${posState.cartItems.fold<int>(0, (sum, item) => sum + item.qty)} Pcs)',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Subtotal:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      Text(
                                        _formatRupiah(posState.subtotal),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Diskon Transaksi:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      InkWell(
                                        onTap: _openDiscountDialog,
                                        child: Text(
                                          posState.totalDiscount > 0
                                              ? '-${_formatRupiah(posState.totalDiscount)}'
                                              : 'Tambah Diskon',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: posState.totalDiscount > 0 ? Colors.red : Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
                                  const Divider(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total Belanja:', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                                      Text(
                                        _formatRupiah(grandTotal),
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // 3. Expandable Payment details
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeInOut,
                                    child: _isPaymentSectionExpanded
                                        ? Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Payment Mode Select
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: ChoiceChip(
                                                      label: const Text('Tunai'),
                                                      selected: _selectedMethod == 'cash',
                                                      onSelected: (val) {
                                                        if (val) setState(() => _selectedMethod = 'cash');
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: ChoiceChip(
                                                      label: const Text('QRIS'),
                                                      selected: _selectedMethod == 'qris',
                                                      onSelected: (val) {
                                                        if (val) setState(() => _selectedMethod = 'qris');
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: ChoiceChip(
                                                      label: const Text('Card/EDC'),
                                                      selected: _selectedMethod == 'bank',
                                                      onSelected: (val) {
                                                        if (val) setState(() => _selectedMethod = 'bank');
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),

                                              // Tunai input & Change calculation
                                              if (_selectedMethod == 'cash') ...[
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 3,
                                                      child: TextField(
                                                        controller: _cashController,
                                                        keyboardType: TextInputType.number,
                                                        decoration: const InputDecoration(
                                                          labelText: 'Uang Diterima',
                                                          prefixText: 'Rp ',
                                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                        ),
                                                        onChanged: _updateCashPaid,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      flex: 2,
                                                      child: ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                        ),
                                                        onPressed: () => _setExactAmount(grandTotal),
                                                        child: const Text('Pas'),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                // Quick Cash Nominal buttons
                                                SingleChildScrollView(
                                                  scrollDirection: Axis.horizontal,
                                                  child: Row(
                                                    children: [10000, 20000, 50000, 100000].map((nom) {
                                                      return Padding(
                                                        padding: const EdgeInsets.only(right: 6.0),
                                                        child: ActionChip(
                                                          label: Text('+${nom ~/ 1000}k'),
                                                          onPressed: () => _addNominal(nom.toDouble()),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                // Kembalian Output
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: change >= 0 ? Colors.green.withOpacity(0.08) : Colors.red.withOpacity(0.08),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        change >= 0 ? 'Kembalian:' : 'Uang Kurang:',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: change >= 0 ? Colors.green : Colors.red,
                                                        ),
                                                      ),
                                                      Text(
                                                        _formatRupiah(change.abs()),
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: change >= 0 ? Colors.green : Colors.red,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                              ],
                                            ],
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  if (_errorMessage != null) ...[
                                    Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 10),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          // 4. Bottom Buttons (Hold & Pay) - Pinned
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                  ),
                                  onPressed: _isProcessing ? null : _openHoldDialog,
                                  icon: const Icon(Icons.pause, size: 20),
                                  label: const Text('Hold', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _isProcessing ? null : () => _processCheckout(grandTotal),
                                  icon: _isProcessing
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Icon(Icons.payment),
                                  label: const Text('Bayar Sekarang', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
    );
  }

  String _formatRupiah(double val) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(val);
  }

  void _showEditQtyDialog(CartItem cartItem) {
    final controller = TextEditingController(text: '${cartItem.qty}');
    bool isRounded = cartItem.isRoundedTo500;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void update() {
              if (context.mounted) {
                setState(() {});
              }
            }
            controller.addListener(update);

            final qty = int.tryParse(controller.text) ?? 0;
            final price = cartItem.price;
            final discount = cartItem.discount;
            final rawSubtotal = (price * qty) - discount;
            final finalSubtotal = isRounded 
                ? (rawSubtotal / 500).ceil() * 500.0 
                : rawSubtotal;

            return AlertDialog(
              title: Text('Edit ${cartItem.item.itemName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah (Qty)',
                      suffixText: 'pcs',
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Bulatkan ke Kelipatan 500',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: isRounded,
                    onChanged: (val) {
                      setState(() {
                        isRounded = val ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal:',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      Text(
                        _formatRupiah(finalSubtotal),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    controller.removeListener(update);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    controller.removeListener(update);
                    final newQty = int.tryParse(controller.text) ?? 0;
                    if (newQty > 0) {
                      ref.read(posNotifierProvider.notifier).updateQty(
                        cartItem.item.itemNo,
                        newQty,
                        isRoundedTo500: isRounded,
                      );
                    } else if (newQty <= 0) {
                      ref.read(posNotifierProvider.notifier).removeFromCart(
                        cartItem.item.itemNo,
                      );
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
