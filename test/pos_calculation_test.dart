import 'package:flutter_test/flutter_test.dart';
import 'package:tokopintar/data/models/item_model.dart';
import 'package:tokopintar/presentation/providers/pos_provider.dart';

void main() {
  group('POS Cart Math Calculations Test', () {
    final mockItem1 = ItemModel(
      itemNo: '001',
      itemUPC: '89901',
      itemName: 'Kopi Susu Gula Aren',
      categoryId: 1,
      price: 15000.0,
    );

    final mockItem2 = ItemModel(
      itemNo: '002',
      itemUPC: '89902',
      itemName: 'Roti Bakar Keju',
      categoryId: 2,
      price: 12000.0,
    );

    test('CartItem price and subtotal calculation without discounts', () {
      final cartItem = CartItem(item: mockItem1, qty: 3);
      
      expect(cartItem.price, 15000.0);
      expect(cartItem.subtotal, 45000.0);
    });

    test('CartItem subtotal calculation with item-level discount', () {
      final cartItem = CartItem(item: mockItem1, qty: 2, discount: 5000.0);
      
      // (15000 * 2) - 5000 = 25000
      expect(cartItem.subtotal, 25000.0);
    });

    test('CartItem subtotal calculation with custom overridden price', () {
      final cartItem = CartItem(item: mockItem1, qty: 2, customPrice: 13000.0);
      
      expect(cartItem.price, 13000.0);
      expect(cartItem.subtotal, 26000.0);
    });

    test('PosState total metrics with multiple items and item discounts', () {
      final items = [
        CartItem(item: mockItem1, qty: 2, discount: 2000.0), // subtotal: 30000 - 2000 = 28000
        CartItem(item: mockItem2, qty: 1), // subtotal: 12000
      ];

      final posState = PosState(cartItems: items);

      // subtotal sum (including item discounts) = 28000 + 12000 = 40000
      expect(posState.subtotal, 40000.0);
      // item discounts total = 2000
      expect(posState.itemDiscountsTotal, 2000.0);
      // grandTotal = 40000
      expect(posState.grandTotal, 40000.0);
    });

    test('PosState total metrics with transaction-level nominal discount', () {
      final items = [
        CartItem(item: mockItem1, qty: 2), // subtotal: 30000
      ];

      final posState = PosState(
        cartItems: items,
        discountType: 'nominal',
        discountValue: 5000.0,
      );

      expect(posState.subtotal, 30000.0);
      expect(posState.transactionDiscount, 5000.0);
      expect(posState.grandTotal, 25000.0);
    });

    test('PosState total metrics with transaction-level percentage discount', () {
      final items = [
        CartItem(item: mockItem1, qty: 2), // subtotal: 30000
      ];

      final posState = PosState(
        cartItems: items,
        discountType: 'percent',
        discountValue: 10.0, // 10%
      );

      expect(posState.subtotal, 30000.0);
      expect(posState.transactionDiscount, 3000.0); // 10% of 30000
      expect(posState.grandTotal, 27000.0);
    });

    test('Change amount calculation bounds', () {
      final items = [
        CartItem(item: mockItem1, qty: 1), // 15000
      ];

      final posState = PosState(cartItems: items);
      final double paid = 20000.0;
      final change = paid - posState.grandTotal;

      expect(change, 5000.0);
    });

    test('PosState total metrics with nearest 500 rounding active', () {
      final items = [
        CartItem(
          item: ItemModel(
            itemNo: '003',
            itemUPC: '89903',
            itemName: 'Aqua',
            categoryId: 1,
            price: 1200.0,
          ),
          qty: 1,
          isRoundedTo500: true,
        ), // subtotal: 1200 rounded up to 1500
        CartItem(item: mockItem2, qty: 1), // subtotal: 12000 (not rounded)
      ];

      final posState = PosState(cartItems: items);

      // subtotal sum (including rounded items) = 1500 + 12000 = 13500
      expect(posState.subtotal, 13500.0);
      // rounding adjustment is no longer active at the state level (it is 0.0)
      expect(posState.roundingAdjustment, 0.0);
      // grandTotal = 13500
      expect(posState.grandTotal, 13500.0);
    });
  });
}
