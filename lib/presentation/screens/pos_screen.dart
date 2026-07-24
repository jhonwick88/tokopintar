import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../domain/services/barcode_service.dart';
import '../../data/models/item_model.dart';
import '../providers/items_provider.dart';
import '../providers/pos_provider.dart';
import '../providers/sales_history_provider.dart';
import '../widgets/camera_scanner_dialog.dart';
import '../widgets/app_permissions_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/main_layout.dart';
import '../widgets/payment_modal.dart';
import 'mobile_cart_screen.dart';
import '../providers/quick_items_provider.dart';
import 'quick_add_item_settings_screen.dart';
import '../widgets/voice_search_button.dart';
import '../widgets/floating_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _catalogScrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isGridView = true;
  bool _isPaymentModalOpen = false;

  @override
  void initState() {
    super.initState();
    _catalogScrollController.addListener(_onScroll);
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _loadViewPreference();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptPermissions();
      if (mounted) {
        final settings = ref.read(settingsNotifierProvider);
        if (settings.enableFloatingCalculator) {
          FloatingCalculatorService.show(context);
        }
      }
    });
  }

  Future<void> _checkAndPromptPermissions() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    final camera = await Permission.camera.isGranted;
    final location = await Permission.locationWhenInUse.isGranted;
    final mic = await Permission.microphone.isGranted;
    final btConnect = await Permission.bluetoothConnect.isGranted;
    final btScan = await Permission.bluetoothScan.isGranted;

    if (!camera || !location || !mic || !btConnect || !btScan) {
      if (mounted) {
        await AppPermissionsDialog.show(context);
      }
    }
  }

  Future<void> _loadViewPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isGridView = prefs.getBool('pos_is_grid_view') ?? true;
      });
    } catch (e) {
      debugPrint('Error loading view preference: $e');
    }
  }

  Future<void> _toggleViewPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isGridView = !_isGridView;
        prefs.setBool('pos_is_grid_view', _isGridView);
      });
    } catch (e) {
      debugPrint('Error saving view preference: $e');
    }
  }

  @override
  void dispose() {
    FloatingCalculatorService.hide();
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _searchFocusNode.dispose();
    _keyboardFocusNode.dispose();
    _searchController.dispose();
    _catalogScrollController.dispose();
    _categoryScrollController.dispose();
    _audioPlayer.dispose();
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
    try {
      await _audioPlayer.play(AssetSource('sounds/scanner-beep.mp3'));
    } catch (e) {
      debugPrint('Gagal memutar suara scan: $e');
    }

    final item = await ref.read(itemsNotifierProvider.notifier).fetchItemByBarcode(barcode);
    if (item != null) {
      ref.read(posNotifierProvider.notifier).addToCart(item);
      _showSuccessToast('Produk ${item.itemName}');
    } else {
      _showUnregisteredBarcodeDialog(barcode);
    }
  }

  void _showSuccessToast(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    if (isDesktop) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: msg.toUpperCase(),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        maxLines: 1,
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final contentWidth = (textPainter.width + 80 + 52).clamp(350.0, width - 128);
      final sideMargin = (width - contentWidth) / 2;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    msg.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ],
            ),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: EdgeInsets.only(bottom: 64, left: sideMargin, right: sideMargin),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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

  void _handleVoiceSearchResult(String words) async {
    if (words.trim().isEmpty) return;
    
    final itemsState = ref.read(itemsNotifierProvider);
    final query = words.toLowerCase().trim();
    
    // exact match check
    final exactMatches = itemsState.items.where((i) {
      return i.itemName.toLowerCase() == query || i.itemNo.toLowerCase() == query;
    }).toList();

    if (exactMatches.length == 1) {
      // Auto Add to Cart
      final matchedItem = exactMatches.first;
      ref.read(posNotifierProvider.notifier).addToCart(matchedItem);
      _showSuccessToast('Produk ${matchedItem.itemName}');
      try {
        await _audioPlayer.play(AssetSource('sounds/scanner-beep.mp3'));
      } catch (_) {}
      
      _searchController.clear();
      ref.read(itemsNotifierProvider.notifier).search('');
    } else {
      // Fallback to normal search filter
      _searchController.text = words;
      ref.read(itemsNotifierProvider.notifier).search(words);
    }
  }

  // --- KEYBOARD SHORTCUTS CONTROLLER ---
  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (_isPaymentModalOpen) return false;
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.f2) {
      _openCameraScanner();
      return true;
    } else if (key == LogicalKeyboardKey.f3) {
      _searchFocusNode.requestFocus();
      return true;
    } else if (key == LogicalKeyboardKey.f4) {
      _openPaymentCheckout();
      return true;
    } else if (key == LogicalKeyboardKey.f8) {
      _reprintLastNota();
      return true;
    } else if (key == LogicalKeyboardKey.f5) {
      if (_searchController.text.isNotEmpty) {
        _searchController.clear();
        ref.read(itemsNotifierProvider.notifier).search('');
        _searchFocusNode.requestFocus();
        return true;
      }
    } else if (key == LogicalKeyboardKey.escape) {
      _voidCurrentCart();
      return true;
    }
    return false;
  }

  Future<void> _openCameraScanner() async {
    var status = await Permission.camera.status;
    if (status != PermissionStatus.granted) {
      if (mounted) {
        await AppPermissionsDialog.show(context);
      }
      status = await Permission.camera.status;
      if (status != PermissionStatus.granted) {
        return;
      }
    }

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
    
    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width >= 900;
    if (!isLargeScreen) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const MobileCartScreen()),
      );
      return;
    }

    setState(() {
      _isPaymentModalOpen = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PaymentModal(),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isPaymentModalOpen = false;
        });
      }
    });
  }

  void _reprintLastNota() async {
    final success = await ref.read(salesHistoryNotifierProvider.notifier).reprintLastReceipt();
    if (success) {
      _showSuccessToast('Cetak ulang nota berhasil dikirim.');
    } else {
      _showErrorToast('Gagal cetak ulang. Riwayat transaksi kosong!');
    }
  }

  void _openQuickItemsBottomSheet() {
    ref.read(quickItemsNotifierProvider.notifier).loadQuickItems();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final quickItems = ref.watch(quickItemsNotifierProvider);
            final activeItems = quickItems.where((item) => item.isActive).toList();

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quick Add Item',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (activeItems.isNotEmpty)
                        Text(
                          '${activeItems.length} Shortcut',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (activeItems.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Column(
                          children: [
                            const Icon(Icons.bolt, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            const Text(
                              'Belum ada Quick Item aktif.',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const QuickAddItemSettingsScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.settings),
                              label: const Text('Konfigurasi Sekarang'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: GridView.builder(
                        shrinkWrap: true,
                        itemCount: activeItems.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.1,
                        ),
                        itemBuilder: (context, index) {
                          final item = activeItems[index];
                          final iconData = quickItemIconsMap[item.iconName] ?? Icons.bolt;
                          final cardColor = item.colorHex != null 
                              ? Color(int.parse(item.colorHex!)) 
                              : Colors.teal;

                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: cardColor.withOpacity(0.2), width: 1),
                            ),
                            color: Theme.of(context).cardColor,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final itemsState = ref.read(itemsNotifierProvider);
                                ItemModel? matchedItem;
                                
                                for (var it in itemsState.items) {
                                  if (it.itemNo == item.itemNo) {
                                    matchedItem = it;
                                    break;
                                  }
                                }

                                if (matchedItem == null) {
                                  matchedItem = await ref.read(itemsNotifierProvider.notifier).fetchItemByBarcode(item.itemNo);
                                }

                                if (matchedItem != null) {
                                  ref.read(posNotifierProvider.notifier).addToCart(matchedItem);
                                  
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.only(bottom: 80, left: 24, right: 24),
                                      content: Row(
                                        children: [
                                          Icon(iconData, color: Colors.white, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text('${item.itemName} ditambahkan ke keranjang'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Produk ${item.itemName} (${item.itemNo}) tidak ditemukan di server'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: cardColor.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        iconData,
                                        color: cardColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.itemName,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
          },
        );
      },
    );
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

    ref.listen<String?>(scannedBarcodeProvider, (previous, next) {
      if (next != null) {
        _onBarcodeScanned(next);
        ref.read(scannedBarcodeProvider.notifier).state = null;
      }
    });

    ref.listen(settingsNotifierProvider, (previous, next) {
      if (previous?.enableFloatingCalculator != next.enableFloatingCalculator) {
        if (next.enableFloatingCalculator) {
          FloatingCalculatorService.show(context);
        } else {
          FloatingCalculatorService.hide();
        }
      }
    });

    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width >= 900;

    return BarcodeKeyboardListener(
      onBarcodeScanned: _onBarcodeScanned,
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
                : _buildCatalogSection(itemsState),
          ),
        ),
      );
  }

  Widget _buildCatalogSection(ItemsState state) {
    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width >= 900;
    final displayItems = state.sortedItems;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Row(
            children: [
              if (isLargeScreen)
                Expanded(
                  child: TextField(
                    focusNode: _searchFocusNode,
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Cari produk berdasarkan nama... (F3)',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state.searchQuery.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: 'Hapus Pencarian (F5)',
                              onPressed: () {
                                _searchController.clear();
                                ref.read(itemsNotifierProvider.notifier).search('');
                              },
                            ),
                          VoiceSearchButton(onResult: _handleVoiceSearchResult),
                        ],
                      ),
                    ),
                    onChanged: (val) {
                      ref.read(itemsNotifierProvider.notifier).search(val.trim());
                    },
                  ),
                ),
              if (isLargeScreen) ...[
                const SizedBox(width: 12),
                Tooltip(
                  message: 'Scan Barcode Kamera (F2)',
                  child: IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    onPressed: _openCameraScanner,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Lanjutkan Transaksi Ditahan',
                  child: IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.orange[800],
                      backgroundColor: Colors.orange.withOpacity(0.12),
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.hourglass_empty_rounded, size: 20),
                    onPressed: _openResumeDialog,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Muat Ulang Katalog (Refresh)',
                  child: IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () {
                      ref.read(itemsNotifierProvider.notifier).initCatalog();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Panduan Penggunaan & Shortcut Keyboard',
                  child: IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.teal[800],
                      backgroundColor: Colors.teal.withOpacity(0.12),
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.help_outline, size: 20),
                    onPressed: _showKeyboardShortcutsGuide,
                  ),
                ),
              ],
              

            ],
          ),
         // ,
          isLargeScreen? const SizedBox(height: 16) : SizedBox(height: 2),
          // Row 2: Categories filter
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                ui.PointerDeviceKind.touch,
                ui.PointerDeviceKind.mouse,
              },
            ),
            child: Scrollbar(
              controller: _categoryScrollController,
              thumbVisibility: false,
              child: SingleChildScrollView(
                controller: _categoryScrollController,
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: state.sortByPrice != 'none'
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                              : null,
                          foregroundColor: state.sortByPrice != 'none'
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        icon: Icon(
                          state.sortByPrice == 'asc'
                              ? Icons.arrow_upward
                              : state.sortByPrice == 'desc'
                                  ? Icons.arrow_downward
                                  : Icons.sort_by_alpha_outlined,
                          size: 20,
                        ),
                        onPressed: () {
                          final current = state.sortByPrice;
                          final next = current == 'none'
                              ? 'asc'
                              : current == 'asc'
                                  ? 'desc'
                                  : 'none';
                          ref.read(itemsNotifierProvider.notifier).toggleSortByPrice(next);
                        },
                        tooltip: 'Sortir Harga',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, size: 20),
                        onPressed: _toggleViewPreference,
                        tooltip: _isGridView ? 'Tampilan List' : 'Tampilan Grid',
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.bolt, color: Colors.teal, size: 18),
                        label: const Text(
                          'Quick Add',
                          style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Colors.teal.withOpacity(0.08),
                        side: BorderSide(color: Colors.teal.withOpacity(0.3)),
                        onPressed: _openQuickItemsBottomSheet,
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Semua Produk'),
                        selected: state.selectedCategoryId == null,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                        labelStyle: TextStyle(
                          color: state.selectedCategoryId == null
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: state.selectedCategoryId == null ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: state.selectedCategoryId == null
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.withOpacity(0.25),
                          ),
                        ),
                        showCheckmark: false,
                        onSelected: (val) {
                          if (val) ref.read(itemsNotifierProvider.notifier).selectCategory(null);
                        },
                      ),
                      ...state.categories.map((cat) {
                        final isSelected = state.selectedCategoryId == cat.id;
                        return Padding(
                           padding: const EdgeInsets.only(left: 8.0),
                           child: ChoiceChip(
                             label: Text(cat.name),
                             selected: isSelected,
                             selectedColor: Theme.of(context).colorScheme.primary,
                             backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                             labelStyle: TextStyle(
                               color: isSelected
                                   ? Colors.white
                                   : Theme.of(context).colorScheme.onSurface,
                               fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                               fontSize: 13,
                             ),
                             shape: RoundedRectangleBorder(
                               borderRadius: BorderRadius.circular(10),
                               side: BorderSide(
                                 color: isSelected
                                     ? Theme.of(context).colorScheme.primary
                                     : Colors.grey.withOpacity(0.25),
                               ),
                             ),
                             showCheckmark: false,
                             onSelected: (val) {
                               if (val) ref.read(itemsNotifierProvider.notifier).selectCategory(cat.id);
                             },
                           ),
                         );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Row 3: Product Grid/List Catalog
          Expanded(
            child: displayItems.isEmpty
                ? Center(
                    child: state.isLoading
                        ? const CircularProgressIndicator()
                        : state.errorMessage != null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.cloud_off_rounded,
                                    size: 64,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Gagal Terhubung ke Server',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      ref.read(itemsNotifierProvider.notifier).initCatalog();
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Coba Hubungkan Kembali'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Tidak ada produk ditemukan',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _openAddProductPage(itemName: state.searchQuery);
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Tambah Produk Baru'),
                                  ),
                                ],
                              ),
                  )
                : _isGridView
                    ? GridView.builder(
                        controller: _catalogScrollController,
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: isLargeScreen ? 180 : 130,
                          childAspectRatio: isLargeScreen ? 0.72 : 0.65,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: displayItems.length + (state.isLoading ? 6 : 0),
                        itemBuilder: (context, index) {
                          if (index >= displayItems.length) {
                            return const Card(child: Center(child: CircularProgressIndicator()));
                          }
                          final product = displayItems[index];
                          final isOutOfStock = product.obQuantity <= 0;
                          final isLowStock = product.obQuantity > 0 && product.obQuantity <= 5;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                ref.read(posNotifierProvider.notifier).addToCart(product);
                              },
                              onLongPress: () => _showEditProductDialog(product),
                              borderRadius: BorderRadius.circular(16),
                              hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                              focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                              highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.withOpacity(0.12)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
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
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'SKU: ${product.itemNo}',
                                              style: const TextStyle(fontSize: 9.5, color: Colors.grey),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            // Stock Alert Badge
                                            Row(
                                              children: [
                                                Icon(
                                                  isOutOfStock
                                                      ? Icons.cancel_outlined
                                                      : isLowStock
                                                          ? Icons.warning_amber_rounded
                                                          : Icons.check_circle_outline_rounded,
                                                  size: 11,
                                                  color: isOutOfStock
                                                      ? Colors.red
                                                      : isLowStock
                                                          ? Colors.orange
                                                          : Colors.green,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    isOutOfStock
                                                        ? 'Habis'
                                                        : isLowStock
                                                            ? '${product.obQuantity.toStringAsFixed(0)} (Tipis)'
                                                            : 'Stok: ${product.obQuantity.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: isLowStock || isOutOfStock ? FontWeight.bold : FontWeight.normal,
                                                      color: isOutOfStock
                                                          ? Colors.red
                                                          : isLowStock
                                                              ? Colors.orange
                                                              : Colors.grey[600],
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
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
                            ),
                          );
                        },
                      )
                    : ListView.separated(
                        controller: _catalogScrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: displayItems.length + (state.isLoading ? 3 : 0),
                        separatorBuilder: (context, index) => const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          if (index >= displayItems.length) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                            );
                          }
                          final product = displayItems[index];
                          final isOutOfStock = product.obQuantity <= 0;
                          final isLowStock = product.obQuantity > 0 && product.obQuantity <= 5;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                ref.read(posNotifierProvider.notifier).addToCart(product);
                                _showSuccessToast('${product.itemName}');
                              },
                              onLongPress: () => _showEditProductDialog(product),
                              borderRadius: BorderRadius.circular(12),
                              hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                              focusColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                              highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.withOpacity(0.12)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.01),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.itemName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  'SKU: ${product.itemNo}',
                                                  style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                                ),
                                                const SizedBox(width: 8),
                                                Text('•', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  isOutOfStock
                                                      ? Icons.cancel_outlined
                                                      : isLowStock
                                                          ? Icons.warning_amber_rounded
                                                          : Icons.check_circle_outline_rounded,
                                                  size: 11,
                                                  color: isOutOfStock
                                                      ? Colors.red
                                                      : isLowStock
                                                          ? Colors.orange
                                                          : Colors.green,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isOutOfStock
                                                      ? 'Habis'
                                                      : isLowStock
                                                          ? 'Stok: ${product.obQuantity.toStringAsFixed(0)} (Tipis)'
                                                          : 'Stok: ${product.obQuantity.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: isLowStock || isOutOfStock ? FontWeight.bold : FontWeight.normal,
                                                    color: isOutOfStock
                                                        ? Colors.red
                                                        : isLowStock
                                                            ? Colors.orange
                                                            : Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _formatRupiah(product.price),
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ],
                                  ),
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
                    return Dismissible(
                      key: Key('desktop-cart-${cartItem.item.itemNo}'),
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
                        _showSuccessToast('${cartItem.item.itemName} dihapus dari keranjang');
                      },
                      child: Card(
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
                                      InkWell(
                                        onTap: () => _showEditQtyDialog(cartItem),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${cartItem.qty}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSummaryRow(
                    'Total Barang',
                    '${state.cartItems.length} Jenis (${state.cartItems.fold<int>(0, (sum, item) => sum + item.qty)} Pcs)',
                  ),
                  const SizedBox(height: 4),
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
                  if (state.enableServiceCharge && state.serviceCharge > 0) ...[
                    const SizedBox(height: 4),
                    _buildSummaryRow('Service Charge (${state.serviceChargePercentage.toInt()}%)', _formatRupiah(state.serviceCharge)),
                  ],
                  if (state.enableTax && state.tax > 0) ...[
                    const SizedBox(height: 4),
                    _buildSummaryRow('Pajak PPN (${state.taxPercentage.toInt()}%)', _formatRupiah(state.tax)),
                  ],
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

  void _showUnregisteredBarcodeDialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.orange,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title
                const Text(
                  'Barcode Tidak Dikenal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Subtitle
                Text(
                  'Sistem tidak menemukan produk untuk barcode ini:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Barcode Container
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.barcode_reader, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        barcode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Action Buttons
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openAddProductPage(barcode: barcode);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Daftarkan Produk Baru', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openQuickMappingWizard(barcode);
                  },
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Petakan ke Produk', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Batal',
                    style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showKeyboardShortcutsGuide() {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.keyboard_outlined, color: colorScheme.primary),
              const SizedBox(width: 12),
              const Text('Panduan & Shortcut Keyboard'),
            ],
          ),
          content: SizedBox(
            width: 550,
            child: DefaultTabController(
              length: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: colorScheme.primary,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.keyboard),
                        text: 'Shortcut Keyboard',
                      ),
                      Tab(
                        icon: Icon(Icons.menu_book),
                        text: 'Panduan POS',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 320,
                    child: TabBarView(
                      children: [
                        // Section 1: Shortcut Keyboard
                        ListView(
                          shrinkWrap: true,
                          children: [
                            _buildShortcutRow(context, 'F2', 'Buka kamera pemindai barcode / QR code.'),
                            _buildShortcutRow(context, 'F3', 'Arahkan fokus kursor langsung ke kolom pencarian produk.'),
                            _buildShortcutRow(context, 'F4', 'Buka modal pembayaran transaksi (Checkout).'),
                            _buildShortcutRow(context, 'F5', 'Hapus kata kunci pencarian aktif jika kolom pencarian ada isinya.'),
                            _buildShortcutRow(context, 'F6', 'Selesaikan transaksi dan tutup dialog sukses transaksi.'),
                            _buildShortcutRow(context, 'F8', 'Cetak ulang struk/nota pembayaran terakhir.'),
                            _buildShortcutRow(context, 'ESC / Escape', 'Kosongkan keranjang belanja (Void semua item).'),
                          ],
                        ),
                        // Section 2: Panduan POS
                        ListView(
                          shrinkWrap: true,
                          children: [
                            _buildGuideStep(
                              context,
                              '1',
                              'Pencarian & Scan',
                              'Ketik nama produk di kolom pencarian atau scan barcode produk menggunakan scanner hardware (langsung) atau scanner kamera (F2).',
                            ),
                            _buildGuideStep(
                              context,
                              '2',
                              'Kelola Keranjang',
                              'Tekan produk untuk menambahkan ke keranjang. Di sisi kanan, Anda bisa menekan item keranjang untuk mengubah kuantitas atau menghapus produk.',
                            ),
                            _buildGuideStep(
                              context,
                              '3',
                              'Diskon & Transaksi',
                              'Tambahkan diskon per item di dalam keranjang, atau berikan diskon global di panel ringkasan belanja.',
                            ),
                            _buildGuideStep(
                              context,
                              '4',
                              'Pembayaran',
                              'Tekan tombol "Bayar" (F4), masukkan nominal uang yang diterima pelanggan, lalu selesaikan transaksi untuk mencetak nota.',
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
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildShortcutRow(BuildContext context, String keyText, String description) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                keyText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                description,
                style: const TextStyle(fontSize: 13, height: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(BuildContext context, String stepNumber, String title, String description) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: colorScheme.secondaryContainer,
            child: Text(
              stepNumber,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openQuickMappingWizard(String barcode) async {
    final selectedProduct = await showModalBottomSheet<ItemModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => const _QuickMappingSearchBottomSheet(),
    );

    if (selectedProduct == null) return;

    _showMappingConfirmationDialog(selectedProduct, barcode);
  }

  void _showMappingConfirmationDialog(ItemModel product, String barcode) {
    final barcodeController = TextEditingController(text: barcode);
    final skuController = TextEditingController(text: product.itemNo);

    showDialog(
      context: context,
      builder: (context) {
        final isSmallScreen = MediaQuery.of(context).size.width < 600;
        return AlertDialog(
          title: Text(
            'Konfirmasi Pemetaan Barcode',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Produk: ${product.itemName}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 13 : 16,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Barcode / UPC (itemUPC)',
                  hintText: 'Masukkan Barcode',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: skuController,
                decoration: const InputDecoration(
                  labelText: 'SKU / Kode Item (itemNo)',
                  hintText: 'Masukkan SKU',
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
              onPressed: () async {
                final newBarcode = barcodeController.text.trim();
                final newSKU = skuController.text.trim();

                if (newBarcode.isEmpty || newSKU.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Barcode dan SKU tidak boleh kosong')),
                  );
                  return;
                }

                Navigator.of(context).pop();

                try {
                  final updatedItem = await ref.read(itemsNotifierProvider.notifier).updateItemKeys(
                    originalItemNo: product.itemNo,
                    newItemNo: newSKU,
                    itemUPC: newBarcode,
                    price: product.price,
                    itemName: product.itemName,
                  );

                  ref.read(posNotifierProvider.notifier).addToCart(updatedItem);

                  _showSuccessToast('Pemetaan berhasil. Produk ditambahkan ke keranjang.');
                } catch (e) {
                  final cleanMsg = _cleanErrorMessage(e, 'Gagal memetakan barcode');
                  _showErrorToast(cleanMsg);
                  debugPrint('Gagal memetakan barcode: $e');
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showEditProductDialog(ItemModel product) {
    final nameController = TextEditingController(text: product.itemName);
    final barcodeController = TextEditingController(text: product.itemUPC);
    final skuController = TextEditingController(text: product.itemNo);
    final priceController = TextEditingController(text: product.price.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('Edit Produk'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Produk (itemName)',
                    prefixIcon: Icon(Icons.shopping_bag),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: barcodeController,
                  decoration: InputDecoration(
                    labelText: 'Barcode / UPC (Opsional)',
                    prefixIcon: const Icon(Icons.qr_code),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () async {
                        var status = await Permission.camera.status;
                        if (status != PermissionStatus.granted) {
                          if (context.mounted) {
                            await AppPermissionsDialog.show(context);
                          }
                          status = await Permission.camera.status;
                          if (status != PermissionStatus.granted) {
                            return;
                          }
                        }
                        
                        if (!context.mounted) return;
                        final scanned = await showDialog<String>(
                          context: context,
                          builder: (context) => const CameraScannerDialog(),
                        );
                        if (scanned != null) {
                          barcodeController.text = scanned;
                        }
                      },
                      tooltip: 'Scan Barcode',
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: skuController,
                  decoration: InputDecoration(
                    labelText: 'SKU / Kode Item (itemNo)',
                    prefixIcon: const Icon(Icons.inventory_2),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.auto_awesome, color: Colors.blue),
                          onPressed: () {
                            skuController.text = generateSKUFromName(nameController.text);
                          },
                          tooltip: 'Generate SKU Otomatis',
                        ),
                        IconButton(
                          icon: const Icon(Icons.help_outline, color: Colors.grey),
                          onPressed: () => _showSKUGuideDialog(context),
                          tooltip: 'Panduan Aturan SKU',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Harga (price)',
                    prefixIcon: Icon(Icons.monetization_on),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                final newBarcode = barcodeController.text.trim();
                final newSKU = skuController.text.trim();
                final priceText = priceController.text.trim();
                final newPrice = double.tryParse(priceText) ?? 0.0;

                if (newName.isEmpty || newSKU.isEmpty || priceText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama Produk, SKU, dan Harga wajib diisi')),
                  );
                  return;
                }

                Navigator.of(context).pop();

                try {
                  await ref.read(itemsNotifierProvider.notifier).updateItemKeys(
                    originalItemNo: product.itemNo,
                    newItemNo: newSKU,
                    itemUPC: newBarcode,
                    price: newPrice,
                    itemName: newName,
                  );
                  _showSuccessToast('Produk berhasil diperbarui');
                } catch (e) {
                  final cleanMsg = _cleanErrorMessage(e, 'Gagal memperbarui produk');
                  _showErrorToast(cleanMsg);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _openAddProductPage({String? barcode, String? itemName}) {
    Navigator.of(context).push(
      MaterialPageRoute<ItemModel>(
        fullscreenDialog: true,
        builder: (context) => _AddProductDialog(
          initialBarcode: barcode,
          initialItemName: itemName,
        ),
      ),
    ).then((newItem) {
      if (newItem != null) {
        ref.read(posNotifierProvider.notifier).addToCart(newItem);
        _showSuccessToast('Produk ${newItem.itemName} ditambahkan ke keranjang');
      }
    });
  }

  void _showEditQtyDialog(CartItem cartItem) {
    final controller = TextEditingController(text: '${cartItem.qty}');
    bool isRounded = cartItem.isRoundedTo500;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Update UI dynamically on text changes
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

class _QuickMappingSearchBottomSheet extends ConsumerStatefulWidget {
  const _QuickMappingSearchBottomSheet();

  @override
  ConsumerState<_QuickMappingSearchBottomSheet> createState() => _QuickMappingSearchBottomSheetState();
}

class _QuickMappingSearchBottomSheetState extends ConsumerState<_QuickMappingSearchBottomSheet> {
  String _searchQuery = '';
  List<ItemModel> _filteredItems = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await ref.read(itemsRepositoryProvider).getItems(page: 1, limit: 100);
      setState(() {
        _filteredItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat produk dari server';
      });
    }
  }

  Future<void> _filter(String val) async {
    final query = val.trim();
    if (query.isEmpty) {
      _fetchItems();
      return;
    }
    setState(() {
      _searchQuery = query;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _performMultiWordSearch(query, page: 1, limit: 100);
      if (_searchQuery == query) {
        setState(() {
          _filteredItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (_searchQuery == query) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal mencari produk';
        });
      }
    }
  }

  Future<List<ItemModel>> _performMultiWordSearch(String query, {required int page, required int limit}) async {
    final queryWords = query
        .toLowerCase()
        .split(' ')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();

    if (queryWords.isEmpty) return [];

    final allResults = <ItemModel>[];
    final seenIds = <String>{};
    final itemsRepository = ref.read(itemsRepositoryProvider);

    // If single word, query directly. Otherwise, merge results of all query words.
    if (queryWords.length == 1) {
      try {
        final results = await itemsRepository.searchItems(
          queryWords[0],
          page: 1,
          limit: limit * 3, // Fetch more to enable local filtering/sorting
        );
        for (final item in results) {
          if (seenIds.add(item.itemNo)) {
            allResults.add(item);
          }
        }
      } catch (e) {
        debugPrint('Error searching for single word: $e');
      }
    } else {
      for (final word in queryWords) {
        try {
          final results = await itemsRepository.searchItems(
            word,
            page: 1,
            limit: limit * 3, // Fetch more to enable local filtering/sorting
          );
          for (final item in results) {
            if (seenIds.add(item.itemNo)) {
              allResults.add(item);
            }
          }
        } catch (e) {
          debugPrint('Error searching for word "$word": $e');
        }
      }
    }

    // Filter: MUST contain ALL query words (case-insensitive)
    final filteredResults = <ItemModel>[];
    for (final item in allResults) {
      final name = item.itemName.toLowerCase();
      bool matchesAll = true;
      for (final word in queryWords) {
        if (!name.contains(word)) {
          matchesAll = false;
          break;
        }
      }
      if (matchesAll) {
        filteredResults.add(item);
      }
    }

    // Sort by relevance:
    // 1. Contiguous match (matches exact query phrase)
    // 2. Index of exact match (closer to start of name is better)
    // 3. Length of name (shorter name = tighter match)
    // 4. Alphabetical
    filteredResults.sort((a, b) {
      final aName = a.itemName.toLowerCase();
      final bName = b.itemName.toLowerCase();
      final q = query.toLowerCase();

      final aExact = aName.contains(q);
      final bExact = bName.contains(q);

      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;

      if (aExact && bExact) {
        final aIdx = aName.indexOf(q);
        final bIdx = bName.indexOf(q);
        if (aIdx != bIdx) {
          return aIdx.compareTo(bIdx);
        }
      }

      if (aName.length != bName.length) {
        return aName.length.compareTo(bName.length);
      }

      return aName.compareTo(bName);
    });

    // Local pagination
    final startIndex = (page - 1) * limit;
    if (startIndex < filteredResults.length) {
      return filteredResults.skip(startIndex).take(limit).toList();
    }
    return [];
  }

  String _formatRupiah(double val) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(val);
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double height = MediaQuery.of(context).size.height * 0.75;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pilih Produk untuk Barcode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Search Input
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Cari nama atau kode produk...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 16),
            
            // Results List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () {
                                  if (_searchQuery.isEmpty) {
                                    _fetchItems();
                                  } else {
                                    _filter(_searchQuery);
                                  }
                                },
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        )
                      : _filteredItems.isEmpty
                          ? const Center(child: Text('Produk tidak ditemukan'))
                          : ListView.separated(
                              itemCount: _filteredItems.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 2),
                              itemBuilder: (context, index) {
                                final product = _filteredItems[index];
                                return Card(
                                  margin: EdgeInsets.zero,
                                  child: InkWell(
                                    onTap: () => Navigator.of(context).pop(product),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product.itemName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  'SKU: ${product.itemNo}  •  Stok: ${product.obQuantity.toStringAsFixed(0)}',
                                                  style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            _formatRupiah(product.price),
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
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
      ),
    );
  }
}

class _AddProductDialog extends ConsumerStatefulWidget {
  final String? initialBarcode;
  final String? initialItemName;

  const _AddProductDialog({
    this.initialBarcode,
    this.initialItemName,
  });

  @override
  ConsumerState<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends ConsumerState<_AddProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _barcodeController;
  late TextEditingController _skuController;
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(text: widget.initialBarcode ?? '');
    _skuController = TextEditingController(text: '');
    _nameController = TextEditingController(text: widget.initialItemName ?? '');
    _priceController = TextEditingController(text: '');
    _stockController = TextEditingController(text: '10');

    // Attempt to set a default generated SKU
    _skuController.text = 'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _skuController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = ref.watch(itemsNotifierProvider).categories;
    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }

    InputDecoration buildInputDecoration(String label, String hint, IconData prefixIcon, {Widget? suffixIcon, String? prefixText}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: colorScheme.primary),
        prefixText: prefixText,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 0,
        title: const Text('Tambah Produk Baru', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informasi Produk',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.onSurface),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lengkapi detail produk untuk menambahkannya ke inventaris toko.',
                            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              TextFormField(
                controller: _nameController,
                decoration: buildInputDecoration(
                  'Nama Produk *',
                  'Contoh: Aqua Botol 600ml',
                  Icons.shopping_bag_rounded,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Nama produk tidak boleh kosong';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _skuController,
                decoration: buildInputDecoration(
                  'SKU / Kode Item *',
                  'Contoh: AQUA-600',
                  Icons.vpn_key_rounded,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.auto_awesome, color: Colors.amber),
                        onPressed: () {
                          _skuController.text = generateSKUFromName(_nameController.text);
                        },
                        tooltip: 'Generate SKU Otomatis',
                      ),
                      IconButton(
                        icon: Icon(Icons.help_outline, color: colorScheme.primary),
                        onPressed: () => _showSKUGuideDialog(context),
                        tooltip: 'Panduan Aturan SKU',
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'SKU tidak boleh kosong';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _barcodeController,
                decoration: buildInputDecoration(
                  'Barcode / UPC',
                  'Scan atau ketik barcode',
                  Icons.qr_code_scanner_rounded,
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      icon: Icon(Icons.camera_alt_rounded, color: colorScheme.primary),
                      onPressed: () async {
                        var status = await Permission.camera.status;
                        if (status != PermissionStatus.granted) {
                          if (context.mounted) {
                            await AppPermissionsDialog.show(context);
                          }
                          status = await Permission.camera.status;
                          if (status != PermissionStatus.granted) return;
                        }
                        
                        if (!context.mounted) return;
                        final scanned = await showDialog<String>(
                          context: context,
                          builder: (context) => const CameraScannerDialog(),
                        );
                        if (scanned != null) {
                          _barcodeController.text = scanned;
                        }
                      },
                      tooltip: 'Scan Barcode',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'Kategori & Harga',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                decoration: buildInputDecoration(
                  'Kategori Produk *',
                  'Pilih kategori',
                  Icons.category_rounded,
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: categories.map((cat) {
                  return DropdownMenuItem<int>(
                    value: cat.id,
                    child: Text(cat.name),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategoryId = val;
                  });
                },
                validator: (val) => val == null ? 'Kategori wajib dipilih' : null,
              ),
              const SizedBox(height: 20),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: buildInputDecoration(
                        'Harga Jual *',
                        '0',
                        Icons.payments_rounded,
                        prefixText: 'Rp ',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                        if (double.tryParse(val) == null) return 'Format tidak valid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      decoration: buildInputDecoration(
                        'Stok Awal *',
                        '0',
                        Icons.inventory_rounded,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                        if (double.tryParse(val) == null) return 'Format tidak valid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 48),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    final name = _nameController.text.trim();
                    final sku = _skuController.text.trim();
                    final barcode = _barcodeController.text.trim();
                    final price = double.parse(_priceController.text.trim());
                    final stock = double.parse(_stockController.text.trim());
                    final catId = _selectedCategoryId!;

                    try {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator()),
                      );

                      final newItem = await ref.read(itemsNotifierProvider.notifier).createItem(
                        itemNo: sku,
                        itemName: name,
                        itemUPC: barcode,
                        categoryId: catId,
                        price: price,
                        obQuantity: stock,
                      );

                      Navigator.of(context).pop(); // Dismiss loading
                      Navigator.of(context).pop(newItem); // Return created item
                    } catch (e) {
                      Navigator.of(context).pop(); // Dismiss loading
                      debugPrint('Gagal menyimpan produk: $e');
                      final cleanMsg = _cleanErrorMessage(e, 'Gagal menyimpan produk');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(cleanMsg),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text(
                    'Simpan Produk',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

String _cleanErrorMessage(dynamic error, String defaultMsg) {
  final errorStr = error.toString().toLowerCase();

  if (errorStr.contains('ie_item_itemupc') ||
      (errorStr.contains('duplicate value') && errorStr.contains('itemupc')) ||
      (errorStr.contains('duplicate') && errorStr.contains('barcode')) ||
      (errorStr.contains('duplicate') && errorStr.contains('upc'))) {
    return 'Barcode/UPC ini sudah terdaftar pada produk lain. Silakan periksa kembali daftar produk Anda.';
  }

  if (errorStr.contains('itemno') &&
      (errorStr.contains('duplicate') ||
          errorStr.contains('unique') ||
          errorStr.contains('attempt to store duplicate value'))) {
    return 'SKU/Kode Item ini sudah terdaftar pada produk lain. Silakan gunakan SKU yang berbeda.';
  }

  if (errorStr.contains('connection refused') ||
      errorStr.contains('socketexception') ||
      errorStr.contains('network') ||
      errorStr.contains('failed to connect')) {
    return 'Gagal menghubungkan ke server. Pastikan REST API sudah aktif.';
  }

  String message = error.toString();
  if (message.startsWith('Exception: ')) {
    message = message.substring(11);
  }
  return '$defaultMsg: $message';
}

String generateSKUFromName(String name) {
  if (name.isEmpty) return '';
  
  final upper = name.toUpperCase();
  final words = upper.split(RegExp(r'\s+'));
  
  String suffix = '';
  String number = '';
  List<String> coreWords = [];
  
  // 1. Determine suffix based on packaging type keyword at the end
  final lastWord = words.isNotEmpty ? words.last : '';
  if (lastWord.contains('ECER') || lastWord.contains('PCS') || lastWord.contains('UNIT') || lastWord == 'E') {
    suffix = 'E';
  } else if (lastWord.contains('PAK') || lastWord.contains('PACK') || lastWord == 'P') {
    suffix = 'P';
  } else if (lastWord.contains('DUS') || lastWord.contains('BOX') || lastWord.contains('KARTON') || lastWord.contains('DOOS') || lastWord == 'D') {
    suffix = 'D';
  } else if (lastWord.contains('LUSIN') || lastWord == 'L') {
    suffix = 'L';
  } else if (lastWord.contains('BOTOL') || lastWord == 'B') {
    suffix = 'B';
  } else if (lastWord.contains('KALENG') || lastWord == 'K') {
    suffix = 'K';
  } else if (lastWord.contains('SACHET') || lastWord.contains('SASET') || lastWord == 'S') {
    suffix = 'S';
  }
  
  // Stopwords list
  final stopWords = {'ISI', 'DAN', 'DENGAN', 'YANG', 'UNTUK', 'DI', 'KE', 'DARI', 'FOR', 'THE', 'AND', 'WITH', 'OF'};
  
  // 2. Parse words
  for (int i = 0; i < words.length; i++) {
    final w = words[i];
    
    // Skip suffix word if it is at the end and matched
    if (i == words.length - 1 && suffix.isNotEmpty) continue;
    
    // Skip common stop words
    if (stopWords.contains(w)) continue;
    
    // Look for digits
    final numMatch = RegExp(r'\d+').firstMatch(w);
    if (numMatch != null && number.isEmpty) {
      number = numMatch.group(0) ?? '';
    }
    
    // Extract clean alphabetic part of the word
    final cleanWord = w.replaceAll(RegExp(r'[^A-Z]'), '');
    if (cleanWord.isNotEmpty) {
      coreWords.add(cleanWord);
    }
  }
  
  // 3. Build core abbreviation
  StringBuffer coreAbbr = StringBuffer();
  for (final w in coreWords) {
    if (w.isEmpty) continue;
    
    // Always keep the first letter
    coreAbbr.write(w[0]);
    
    // Keep subsequent consonants
    for (int j = 1; j < w.length; j++) {
      final char = w[j];
      if (char != 'A' && char != 'I' && char != 'U' && char != 'E' && char != 'O') {
        coreAbbr.write(char);
      }
    }
  }
  
  // Combine core + number + suffix
  String sku = coreAbbr.toString() + number + suffix;
  sku = sku.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  
  // Clean and limit length (e.g. max 12 characters to keep it compact)
  if (sku.length > 12) {
    final coreLength = 12 - number.length - suffix.length;
    if (coreLength > 0 && coreAbbr.length > coreLength) {
      sku = coreAbbr.toString().substring(0, coreLength) + number + suffix;
    }
  }
  
  return sku;
}

void _showSKUGuideDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Panduan Penamaan SKU'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aturan Penamaan SKU (Stock Keeping Unit):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                'SKU dibuat dengan menyingkat Nama Produk (mengambil konsonan huruf kapital penting), diikuti detail ukuran/jumlah (jika ada), dan jenis kemasan di ujungnya.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              SizedBox(height: 16),
              Text(
                'Kode Tipe Kemasan (Akhiran):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text('• E = Ecer / Pcs / Unit\n• P = Pak / Pack\n• D = Dus / Box / Karton\n• L = Lusin\n• S = Sachet / Saset\n• B = Botol\n• K = Kaleng', style: TextStyle(fontSize: 13, height: 1.4)),
              SizedBox(height: 16),
              Text(
                'Contoh Kasus:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Divider(),
              SizedBox(height: 4),
              Text(
                '1. Buku Tulis Sinar Dunia Isi 32 Ecer\n   » SKU: BKTLSSD32E\n   (Buku Tulis = BKTLS, Sinar Dunia = SD, 32 = 32, Ecer = E)',
                style: TextStyle(fontSize: 13, height: 1.4, fontFamily: 'monospace'),
              ),
              SizedBox(height: 8),
              Text(
                '2. Buku Tulis Sinar Dunia Isi 32 Pak\n   » SKU: BKTLSSD32P\n   (Buku Tulis = BKTLS, Sinar Dunia = SD, 32 = 32, Pak = P)',
                style: TextStyle(fontSize: 13, height: 1.4, fontFamily: 'monospace'),
              ),
              SizedBox(height: 8),
              Text(
                '3. Kopi Kapal Api Saset\n   » SKU: KPKPLAPS\n   (Kopi = KP, Kapal Api = KPLAP, Saset = S)',
                style: TextStyle(fontSize: 13, height: 1.4, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      );
    },
  );
}

