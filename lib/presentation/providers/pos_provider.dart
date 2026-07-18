import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/item_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/settings_model.dart';
import '../../domain/services/printer_service.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';
import 'sales_history_provider.dart';

class CartItem {
  final ItemModel item;
  final int qty;
  final double? customPrice;
  final String note;
  final double discount; // item level discount nominal
  final bool isRoundedTo500;

  CartItem({
    required this.item,
    this.qty = 1,
    this.customPrice,
    this.note = '',
    this.discount = 0.0,
    this.isRoundedTo500 = false,
  });

  double get price => customPrice ?? item.price;
  double get subtotal {
    final rawSubtotal = (price * qty) - discount;
    if (isRoundedTo500) {
      return (rawSubtotal / 500).ceil() * 500.0;
    }
    return rawSubtotal;
  }

  CartItem copyWith({
    ItemModel? item,
    int? qty,
    double? customPrice,
    String? note,
    double? discount,
    bool? isRoundedTo500,
  }) {
    return CartItem(
      item: item ?? this.item,
      qty: qty ?? this.qty,
      customPrice: customPrice ?? this.customPrice,
      note: note ?? this.note,
      discount: discount ?? this.discount,
      isRoundedTo500: isRoundedTo500 ?? this.isRoundedTo500,
    );
  }
}

class HeldCart {
  final String id;
  final String title;
  final DateTime date;
  final List<CartItem> cartItems;
  final String discountType;
  final double discountValue;

  HeldCart({
    required this.id,
    required this.title,
    required this.date,
    required this.cartItems,
    required this.discountType,
    required this.discountValue,
  });
}

class PosState {
  final List<CartItem> cartItems;
  final String discountType; // 'none', 'nominal', 'percent'
  final double discountValue;
  final List<HeldCart> heldCarts;
  
  // Professional settings addition
  final bool enableTax;
  final double taxPercentage;
  final bool enableServiceCharge;
  final double serviceChargePercentage;

  PosState({
    this.cartItems = const [],
    this.discountType = 'none',
    this.discountValue = 0.0,
    this.heldCarts = const [],
    this.enableTax = false,
    this.taxPercentage = 0.0,
    this.enableServiceCharge = false,
    this.serviceChargePercentage = 0.0,
  });

  double get subtotal {
    return cartItems.fold(0.0, (sum, i) => sum + i.subtotal);
  }

  double get itemDiscountsTotal {
    return cartItems.fold(0.0, (sum, i) => sum + i.discount);
  }

  double get roundingAdjustment {
    return 0.0;
  }

  double get transactionDiscount {
    if (discountType == 'percent') {
      return subtotal * (discountValue / 100);
    } else if (discountType == 'nominal') {
      return discountValue;
    }
    return 0.0;
  }

  double get totalDiscount => itemDiscountsTotal + transactionDiscount;

  double get serviceCharge {
    if (!enableServiceCharge) return 0.0;
    final netSub = subtotal - transactionDiscount;
    return netSub > 0 ? netSub * (serviceChargePercentage / 100) : 0.0;
  }

  double get tax {
    if (!enableTax) return 0.0;
    final netSub = subtotal - transactionDiscount;
    final totalWithService = netSub + serviceCharge;
    return totalWithService > 0 ? totalWithService * (taxPercentage / 100) : 0.0;
  }

  double get grandTotal {
    final netSub = subtotal - transactionDiscount;
    final total = netSub + serviceCharge + tax;
    return total > 0 ? total : 0.0;
  }

  PosState copyWith({
    List<CartItem>? cartItems,
    String? discountType,
    double? discountValue,
    List<HeldCart>? heldCarts,
    bool? enableTax,
    double? taxPercentage,
    bool? enableServiceCharge,
    double? serviceChargePercentage,
  }) {
    return PosState(
      cartItems: cartItems ?? this.cartItems,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      heldCarts: heldCarts ?? this.heldCarts,
      enableTax: enableTax ?? this.enableTax,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      enableServiceCharge: enableServiceCharge ?? this.enableServiceCharge,
      serviceChargePercentage: serviceChargePercentage ?? this.serviceChargePercentage,
    );
  }
}

class PosNotifier extends StateNotifier<PosState> {
  final Ref _ref;

  PosNotifier(this._ref) : super(PosState());

  void addToCart(ItemModel item, {int qty = 1}) {
    final existingIndex = state.cartItems.indexWhere((i) => i.item.itemNo == item.itemNo);
    if (existingIndex >= 0) {
      final existing = state.cartItems[existingIndex];
      _updateItemInList(existingIndex, existing.copyWith(qty: existing.qty + qty));
    } else {
      state = state.copyWith(
        cartItems: [...state.cartItems, CartItem(item: item, qty: qty)],
      );
    }
  }

  void removeFromCart(String itemNo) {
    state = state.copyWith(
      cartItems: state.cartItems.where((i) => i.item.itemNo != itemNo).toList(),
    );
  }

  void updateQty(String itemNo, int qty, {bool? isRoundedTo500}) {
    if (qty <= 0) {
      removeFromCart(itemNo);
      return;
    }
    final idx = state.cartItems.indexWhere((i) => i.item.itemNo == itemNo);
    if (idx >= 0) {
      var cartItem = state.cartItems[idx].copyWith(qty: qty);
      if (isRoundedTo500 != null) {
        cartItem = cartItem.copyWith(isRoundedTo500: isRoundedTo500);
      }
      _updateItemInList(idx, cartItem);
    }
  }

  void updatePrice(String itemNo, double price) {
    final idx = state.cartItems.indexWhere((i) => i.item.itemNo == itemNo);
    if (idx >= 0) {
      _updateItemInList(idx, state.cartItems[idx].copyWith(customPrice: price));
    }
  }

  void updateNote(String itemNo, String note) {
    final idx = state.cartItems.indexWhere((i) => i.item.itemNo == itemNo);
    if (idx >= 0) {
      _updateItemInList(idx, state.cartItems[idx].copyWith(note: note));
    }
  }

  void applyItemDiscount(String itemNo, double discount) {
    final idx = state.cartItems.indexWhere((i) => i.item.itemNo == itemNo);
    if (idx >= 0) {
      _updateItemInList(idx, state.cartItems[idx].copyWith(discount: discount));
    }
  }

  void applyTransactionDiscount(String type, double value) {
    state = state.copyWith(
      discountType: type,
      discountValue: value,
    );
  }

  void clearCart() {
    state = state.copyWith(
      cartItems: [],
      discountType: 'none',
      discountValue: 0.0,
    );
  }

  void _updateItemInList(int index, CartItem newItem) {
    final list = List<CartItem>.from(state.cartItems);
    list[index] = newItem;
    state = state.copyWith(cartItems: list);
  }

  // --- HOLD / RESUME TRANSACTIONS ---
  void holdTransaction(String title) {
    if (state.cartItems.isEmpty) return;

    final held = HeldCart(
      id: const Uuid().v4(),
      title: title.isEmpty ? 'Held ${DateTime.now().hour}:${DateTime.now().minute}' : title,
      date: DateTime.now(),
      cartItems: state.cartItems,
      discountType: state.discountType,
      discountValue: state.discountValue,
    );

    state = state.copyWith(
      heldCarts: [...state.heldCarts, held],
      cartItems: [],
      discountType: 'none',
      discountValue: 0.0,
    );

    // Audit Log
    final user = _ref.read(authNotifierProvider).currentUser;
    if (user != null) {
      _ref.read(auditRepositoryProvider).logActivity(
        user.uid,
        user.username,
        'hold_transaction',
        'Held active cart: "${held.title}"',
      );
    }
  }

  void resumeHeldTransaction(String heldId) {
    final idx = state.heldCarts.indexWhere((h) => h.id == heldId);
    if (idx >= 0) {
      final target = state.heldCarts[idx];
      state = state.copyWith(
        cartItems: target.cartItems,
        discountType: target.discountType,
        discountValue: target.discountValue,
        heldCarts: state.heldCarts.where((h) => h.id != heldId).toList(),
      );

      // Audit Log
      final user = _ref.read(authNotifierProvider).currentUser;
      if (user != null) {
        _ref.read(auditRepositoryProvider).logActivity(
          user.uid,
          user.username,
          'resume_transaction',
          'Resumed held transaction: "${target.title}"',
        );
      }
    }
  }

  void voidHeldTransaction(String heldId) {
    final target = state.heldCarts.firstWhere((h) => h.id == heldId);
    state = state.copyWith(
      heldCarts: state.heldCarts.where((h) => h.id != heldId).toList(),
    );

    // Audit Log
    final user = _ref.read(authNotifierProvider).currentUser;
    if (user != null) {
      _ref.read(auditRepositoryProvider).logActivity(
        user.uid,
        user.username,
        'void_held',
        'Voided held transaction: "${target.title}"',
      );
    }
  }

  // --- CHECKOUT PROCESS ---
  Future<SaleModel?> checkout({
    required String paymentMethod,
    required double paidAmount,
  }) async {
    if (state.cartItems.isEmpty) return null;

    final user = _ref.read(authNotifierProvider).currentUser;
    final cashierName = user?.fullname ?? 'Kasir';
    final cashierId = user?.uid ?? 'unknown';
    final settings = _ref.read(settingsNotifierProvider);

    // Format Invoice No: INVyyyyMMddHHmmss
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final invoiceNo = 'INV$dateStr$timeStr';

    final double change = paidAmount - state.grandTotal;

    // Convert CartItems to SaleItemModels
    final saleItems = state.cartItems.map((c) {
      return SaleItemModel(
        itemNo: c.item.itemNo,
        itemUPC: c.item.itemUPC,
        itemName: c.item.itemName,
        qty: c.qty,
        price: c.price,
        subtotal: c.subtotal,
        note: c.note,
        discount: c.discount,
      );
    }).toList();

    final sale = SaleModel(
      invoiceNo: invoiceNo,
      date: now,
      cashier: cashierName,
      subtotal: state.subtotal,
      discount: state.transactionDiscount,
      tax: state.tax,
      serviceCharge: state.serviceCharge,
      grandTotal: state.grandTotal,
      paymentMethod: paymentMethod,
      paidAmount: paidAmount,
      changeAmount: change > 0 ? change : 0.0,
      status: 'completed',
      items: saleItems,
    );

    try {
      // 1. Save to Firestore
      await _ref.read(salesRepositoryProvider).saveSale(sale);

      // Refresh sales history local state to keep it updated with the new transaction
      _ref.read(salesHistoryNotifierProvider.notifier).fetchSales();

      // 2. Log Activity
      await _ref.read(auditRepositoryProvider).logActivity(
        cashierId,
        user?.username ?? 'kasir',
        'checkout',
        'Completed sale $invoiceNo with total ${_formatCurrency(sale.grandTotal)} via $paymentMethod',
      );

      // 3. Print Receipt
      if (settings.autoPrintOnCheckout) {
        final printBytes = PrinterService.instance.generateReceiptBytes(sale, settings);
        if (settings.printerType == 'LAN') {
          PrinterService.instance.printToLan(settings.printerIp, settings.printerPort, printBytes, copies: settings.printReceiptCopies);
        } else if (settings.printerType == 'Bluetooth') {
          PrinterService.instance.printToBluetooth(settings.printerMacAddress, printBytes, copies: settings.printReceiptCopies);
        } else if (settings.printerType == 'USB') {
          PrinterService.instance.printToWindows(settings.printerMacAddress, sale, settings);
        } else {
          dev.log('Print Job generated. Receipt printed to output pipeline.');
        }
      }

      // 4. Clear active cart
      clearCart();
      return sale;
    } catch (e) {
      dev.log('Checkout failed: $e');
      rethrow;
    }
  }

  void _syncSettings(SettingsModel settings) {
    state = state.copyWith(
      enableTax: settings.enableTax,
      taxPercentage: settings.taxPercentage,
      enableServiceCharge: settings.enableServiceCharge,
      serviceChargePercentage: settings.serviceChargePercentage,
    );
  }

  String _formatCurrency(double amount) {
    final value = amount.toInt();
    final str = value.toString();
    final regExp = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(regExp, (Match m) => '${m[1]}.');
  }
}

final posNotifierProvider = StateNotifierProvider<PosNotifier, PosState>((ref) {
  final notifier = PosNotifier(ref);
  ref.listen<SettingsModel>(settingsNotifierProvider, (prev, next) {
    notifier._syncSettings(next);
  });
  notifier._syncSettings(ref.read(settingsNotifierProvider));
  return notifier;
});

final scannedBarcodeProvider = StateProvider<String?>((ref) => null);
