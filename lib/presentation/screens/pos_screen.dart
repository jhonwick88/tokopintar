import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/services/barcode_service.dart';
import '../providers/items_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/sales_history_provider.dart';
import '../widgets/camera_scanner_dialog.dart';
import '../widgets/main_layout.dart';
import '../widgets/payment_modal.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _catalogScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _catalogScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    _catalogScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_catalogScrollController.position.pixels >=
        _catalogScrollController.position.maxScrollExtent - 200) {
      // Trigger pagination load
      ref.read(itemsNotifierProvider.notifier).loadItems();
    }
  }

  // Handle barcode scanned globally via Keyboard listener or camera
  void _onBarcodeScanned(String barcode) async {
    final item = await ref.read(itemsNotifierProvider.notifier).fetchItemByBarcode(barcode);
    if (item != null) {
      ref.read(posNotifierProvider.notifier).addToCart(item);
      _showSuccessToast('Produk ${item.itemName} ditambahkan');
    } else {
      _showErrorToast('Produk dengan barcode "$barcode" tidak ditemukan');
    }
  }

  void _showSuccessToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- KEYBOARD SHORTCUTS CONTROLLER ---
  void _handleRawKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.f2) {
      _openCameraScanner();
    } else if (key == LogicalKeyboardKey.f3) {
      _searchFocusNode.requestFocus();
    } else if (key == LogicalKeyboardKey.f4) {
      _openPaymentCheckout();
    } else if (key == LogicalKeyboardKey.f8) {
      _reprintLastNota();
    } else if (key == LogicalKeyboardKey.escape) {
      _voidCurrentCart();
    }
  }

  Future<void> _openCameraScanner() async {
    final barcode = await showDialog<String>(
      context: context,
      builder: (context) => const CameraScannerDialog(),
    );
    if (barcode != null) {
      _onBarcodeScanned(barcode);
    }
  }

  void _openPaymentCheckout() {
    final posState = ref.read(posNotifierProvider);
    if (posState.cartItems.isEmpty) {
      _showErrorToast('Keranjang belanja kosong!');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PaymentModal(),
    );
  }

  void _reprintLastNota() async {
    final success = await ref.read(salesHistoryNotifierProvider.notifier).reprintLastReceipt();
    if (success) {
      _showSuccessToast('Cetak ulang nota berhasil dikirim.');
    } else {
      _showErrorToast('Gagal cetak ulang. Riwayat transaksi kosong!');
    }
  }

  void _voidCurrentCart() {
    final cart = ref.read(posNotifierProvider).cartItems;
    if (cart.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Batal Transaksi'),
          content: const Text('Apakah Anda yakin ingin membatalkan transaksi ini dan mengosongkan keranjang?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tidak'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                ref.read(posNotifierProvider.notifier).clearCart();
                Navigator.of(context).pop();
                _showSuccessToast('Transaksi dibatalkan');
              },
              child: const Text('Ya, Batal', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _openHoldDialog() {
    final cart = ref.read(posNotifierProvider).cartItems;
    if (cart.isEmpty) return;

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
                Navigator.of(context).pop();
                _showSuccessToast('Transaksi berhasil ditahan');
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _openResumeDialog() {
    final posState = ref.watch(posNotifierProvider);
    if (posState.heldCarts.isEmpty) {
      _showErrorToast('Tidak ada transaksi yang ditangguhkan.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Daftar Transaksi Ditahan (Resume)'),
          content: Container(
            width: 450,
            height: 300,
            child: ListView.builder(
              itemCount: posState.heldCarts.length,
              itemBuilder: (context, index) {
                final held = posState.heldCarts[index];
                return ListTile(
                  title: Text(held.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Items: ${held.cartItems.length}  |  ${DateFormat('HH:mm').format(held.date)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          ref.read(posNotifierProvider.notifier).voidHeldTransaction(held.id);
                          Navigator.of(context).pop();
                          _showSuccessToast('Transaksi ditangguhkan dihapus');
                        },
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(posNotifierProvider.notifier).resumeHeldTransaction(held.id);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Lanjutkan'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
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
                  hintText: 'Level pedas, ukuran, dll.',
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

  @override
  Widget build(BuildContext context) {
    final itemsState = ref.watch(itemsNotifierProvider);
    final posState = ref.watch(posNotifierProvider);

    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width >= 900;

    return BarcodeKeyboardListener(
      onBarcodeScanned: _onBarcodeScanned,
      child: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: _handleRawKeyEvent,
        child: MainLayout(
          currentRoute: '/pos',
          child: Scaffold(
            body: isLargeScreen
                ? Row(
                    children: [
                      // Catalog Left Pane
                      Expanded(
                        flex: 3,
                        child: _buildCatalogSection(itemsState),
                      ),
                      // Cart Right Pane
                      Container(
                        width: 380,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHigh,
                          border: Border(left: BorderSide(color: Colors.grey.withOpacity(0.12))),
                        ),
                        child: _buildCartSection(posState),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      // Simple toggle cart count header for mobile
                      ListTile(
                        tileColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                        title: Text('${posState.cartItems.length} Item di Keranjang'),
                        subtitle: Text('Total: ${_formatRupiah(posState.grandTotal)}'),
                        trailing: ElevatedButton(
                          onPressed: _openPaymentCheckout,
                          child: const Text('Bayar'),
                        ),
                      ),
                      Expanded(
                        child: _buildCatalogSection(itemsState),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogSection(ItemsState state) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Row 1: Search & Barcode Buttons
          Row(
            children: [
              Expanded(
                child: TextField(
                  focusNode: _searchFocusNode,
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Cari produk berdasarkan nama... (F3)',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (val) {
                    ref.read(itemsNotifierProvider.notifier).search(val.trim());
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _openCameraScanner,
                tooltip: 'Scan Barcode Kamera (F2)',
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.hourglass_empty_rounded),
                onPressed: _openResumeDialog,
                tooltip: 'Lanjutkan Transaksi Ditahan',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Row 2: Categories filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Semua Produk'),
                  selected: state.selectedCategoryId == null,
                  onSelected: (val) {
                    if (val) ref.read(itemsNotifierProvider.notifier).selectCategory(null);
                  },
                ),
                ...state.categories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ChoiceChip(
                      label: Text(cat.name),
                      selected: state.selectedCategoryId == cat.id,
                      onSelected: (val) {
                        if (val) ref.read(itemsNotifierProvider.notifier).selectCategory(cat.id);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Row 3: Product Grid Catalog
          Expanded(
            child: state.items.isEmpty
                ? Center(
                    child: state.isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Tidak ada produk ditemukan'),
                  )
                : GridView.builder(
                    controller: _catalogScrollController,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      childAspectRatio: 0.82,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: state.items.length + (state.isLoading ? 6 : 0),
                    itemBuilder: (context, index) {
                      if (index >= state.items.length) {
                        return const Card(child: Center(child: CircularProgressIndicator()));
                      }
                      final product = state.items[index];
                      return InkWell(
                        onTap: () {
                          ref.read(posNotifierProvider.notifier).addToCart(product);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Mock Image / Initials Placeholder
                                Container(
                                  width: double.infinity,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    product.itemName[0].toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.itemName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        'UPC: ${product.itemUPC}',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatRupiah(product.price),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSection(PosState state) {
    return Column(
      children: [
        // Cart Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Keranjang Belanja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
                onPressed: _voidCurrentCart,
                tooltip: 'Batalkan Semua (ESC)',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        
        // Cart Items Scrollable List
        Expanded(
          child: state.cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('Belum ada item', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: state.cartItems.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final cartItem = state.cartItems[index];
                    return Card(
                      color: Theme.of(context).cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
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
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatRupiah(cartItem.price),
                                        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11),
                                      ),
                                      if (cartItem.discount > 0)
                                        Text(
                                          'Disc: -${_formatRupiah(cartItem.discount)}',
                                          style: const TextStyle(color: Colors.red, fontSize: 10),
                                        ),
                                      if (cartItem.note.isNotEmpty)
                                        Text(
                                          '* Note: ${cartItem.note}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_note, size: 20),
                                  onPressed: () => _openItemNoteAndDiscountDialog(cartItem),
                                  tooltip: 'Edit Catatan & Diskon',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sub: ${_formatRupiah(cartItem.subtotal)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.remove_circle_outline, size: 22),
                                      onPressed: () {
                                        ref.read(posNotifierProvider.notifier).updateQty(
                                              cartItem.item.itemNo,
                                              cartItem.qty - 1,
                                            );
                                      },
                                    ),
                                    Text('${cartItem.qty}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.add_circle_outline, size: 22),
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
                    );
                  },
                ),
        ),
        
        // Cart Summary Actions
        const Divider(height: 1),
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildSummaryRow('Subtotal', _formatRupiah(state.subtotal)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Diskon Transaksi', style: TextStyle(fontSize: 12)),
                  InkWell(
                    onTap: _openDiscountDialog,
                    child: Text(
                      state.totalDiscount > 0 ? '-${_formatRupiah(state.totalDiscount)}' : 'Tambah Diskon',
                      style: TextStyle(
                        fontSize: 12,
                        color: state.totalDiscount > 0 ? Colors.red : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(
                    _formatRupiah(state.grandTotal),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Bottom Grid Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _openHoldDialog,
                      icon: const Icon(Icons.pause, size: 18),
                      label: const Text('Hold'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _openPaymentCheckout,
                      icon: const Icon(Icons.payment),
                      label: const Text('Bayar (F4)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.keyboard_outlined, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'F2: Scan | F3: Cari | F4: Bayar | ESC: Batal',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  String _formatRupiah(double val) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(val);
  }
}
