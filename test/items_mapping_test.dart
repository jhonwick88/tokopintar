import 'package:flutter_test/flutter_test.dart';
import 'package:tokopintar/data/models/category_model.dart';
import 'package:tokopintar/data/models/item_model.dart';
import 'package:tokopintar/domain/repositories/items_repository.dart';
import 'package:tokopintar/presentation/providers/items_provider.dart';
import 'package:tokopintar/presentation/screens/pos_screen.dart';

class MockItemsRepository implements ItemsRepository {
  List<ItemModel> db = [];

  @override
  Future<List<CategoryModel>> getCategories() async {
    return [];
  }

  @override
  Future<List<ItemModel>> getItems({required int page, int limit = 50}) async {
    return db;
  }

  @override
  Future<ItemModel?> getItemByNo(String itemNo) async {
    try {
      return db.firstWhere((it) => it.itemNo == itemNo);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ItemModel>> searchItems(String query, {required int page, int limit = 50}) async {
    return db.where((it) => it.itemName.contains(query)).toList();
  }

  @override
  Future<List<ItemModel>> getItemsByCategory(int categoryId, {required int page, int limit = 50}) async {
    return db.where((it) => it.categoryId == categoryId).toList();
  }

  @override
  Future<ItemModel> updateItemKeys({
    required String originalItemNo,
    required String newItemNo,
    required String itemUPC,
    required double price,
    required String itemName,
  }) async {
    final idx = db.indexWhere((it) => it.itemNo == originalItemNo);
    if (idx < 0) {
      throw Exception('Not found');
    }
    final existing = db[idx];
    final updated = ItemModel(
      itemNo: newItemNo,
      itemUPC: itemUPC,
      itemName: itemName,
      categoryId: existing.categoryId,
      price: price,
    );
    db[idx] = updated;
    return updated;
  }

  @override
  Future<ItemModel> createItem({
    required String itemNo,
    required String itemName,
    required String itemUPC,
    required int categoryId,
    required double price,
    required double obQuantity,
  }) async {
    final newItem = ItemModel(
      itemNo: itemNo,
      itemName: itemName,
      itemUPC: itemUPC,
      categoryId: categoryId,
      price: price,
      obQuantity: obQuantity,
    );
    db.add(newItem);
    return newItem;
  }
}

void main() {
  group('ItemsNotifier updateItemKeys Tests', () {
    late MockItemsRepository mockRepo;
    late ItemsNotifier notifier;

    setUp(() {
      mockRepo = MockItemsRepository();
      mockRepo.db = [
        ItemModel(
          itemNo: 'SKU_1',
          itemUPC: '1111',
          itemName: 'Item Satu',
          categoryId: 1,
          price: 10000,
        ),
        ItemModel(
          itemNo: 'SKU_2',
          itemUPC: '2222',
          itemName: 'Item Dua',
          categoryId: 1,
          price: 20000,
        ),
      ];
      notifier = ItemsNotifier(mockRepo);
    });

    test('updateItemKeys successfully updates SKU and Barcode in repository and local cache state', () async {
      notifier.state = notifier.state.copyWith(items: mockRepo.db);

      final result = await notifier.updateItemKeys(
        originalItemNo: 'SKU_1',
        newItemNo: 'SKU_1_NEW',
        itemUPC: '8991111',
        price: 15000,
        itemName: 'Item Satu Baru',
      );

      expect(result.itemNo, 'SKU_1_NEW');
      expect(result.itemUPC, '8991111');
      expect(result.itemName, 'Item Satu Baru');

      expect(mockRepo.db.first.itemNo, 'SKU_1_NEW');
      expect(mockRepo.db.first.itemUPC, '8991111');
      expect(mockRepo.db.first.itemName, 'Item Satu Baru');

      final updatedItem = notifier.state.items.firstWhere((it) => it.itemName == 'Item Satu Baru');
      expect(updatedItem.itemNo, 'SKU_1_NEW');
      expect(updatedItem.itemUPC, '8991111');
    });

    test('createItem successfully registers a new item in repository and local cache state', () async {
      notifier.state = notifier.state.copyWith(items: mockRepo.db);

      final result = await notifier.createItem(
        itemNo: 'SKU_NEW_PROD',
        itemName: 'Item Baru',
        itemUPC: '8993333',
        categoryId: 2,
        price: 35000,
        obQuantity: 10,
      );

      expect(result.itemNo, 'SKU_NEW_PROD');
      expect(result.itemName, 'Item Baru');
      expect(result.itemUPC, '8993333');
      expect(result.categoryId, 2);
      expect(result.price, 35000);

      expect(mockRepo.db.any((it) => it.itemNo == 'SKU_NEW_PROD'), isTrue);
      expect(notifier.state.items.any((it) => it.itemNo == 'SKU_NEW_PROD'), isTrue);
    });
  });

  group('ItemsNotifier Category and Search Filtering Tests', () {
    late MockItemsRepository mockRepo;
    late ItemsNotifier notifier;

    setUp(() async {
      mockRepo = MockItemsRepository();
      mockRepo.db = [
        ItemModel(
          itemNo: 'SKU_1',
          itemUPC: '1111',
          itemName: 'Bola Basket',
          categoryId: 1, // Sports
          price: 150000,
        ),
        ItemModel(
          itemNo: 'SKU_2',
          itemUPC: '2222',
          itemName: 'Bola Lampu',
          categoryId: 2, // Electronics
          price: 15000,
        ),
        ItemModel(
          itemNo: 'SKU_3',
          itemUPC: '3333',
          itemName: 'Sepatu Lari',
          categoryId: 1, // Sports
          price: 300000,
        ),
      ];
      notifier = ItemsNotifier(mockRepo);
      await Future.delayed(const Duration(milliseconds: 50));
      while (notifier.state.isLoading) {
        await Future.delayed(const Duration(milliseconds: 5));
      }
    });

    test('Searching "Bola" globally shows both Bola Basket and Bola Lampu', () async {
      await notifier.search('Bola');
      expect(notifier.state.items.length, 2);
      expect(notifier.state.items.any((it) => it.itemName == 'Bola Basket'), isTrue);
      expect(notifier.state.items.any((it) => it.itemName == 'Bola Lampu'), isTrue);
      expect(notifier.state.selectedCategoryId, isNull);
    });

    test('Selecting a category after searching "Bola" filters matches to that category only', () async {
      await notifier.search('Bola');
      await notifier.selectCategory(1); // Sports

      expect(notifier.state.searchQuery, 'Bola');
      expect(notifier.state.selectedCategoryId, 1);
      expect(notifier.state.items.length, 1);
      expect(notifier.state.items.first.itemName, 'Bola Basket');
    });

    test('Clearing category back to null (Semua Produk) retains search query and returns all search results', () async {
      await notifier.search('Bola');
      await notifier.selectCategory(1); // Sports
      await notifier.selectCategory(null); // Semua Produk

      expect(notifier.state.searchQuery, 'Bola');
      expect(notifier.state.selectedCategoryId, isNull);
      expect(notifier.state.items.length, 2);
    });

    test('Sorting search results by price asc and desc works correctly', () async {
      await notifier.search('Bola');
      
      // Sort Ascending
      notifier.toggleSortByPrice('asc');
      expect(notifier.state.sortByPrice, 'asc');
      var sorted = notifier.state.sortedItems;
      expect(sorted[0].itemName, 'Bola Lampu'); // Price 15000
      expect(sorted[1].itemName, 'Bola Basket'); // Price 150000

      // Sort Descending
      notifier.toggleSortByPrice('desc');
      expect(notifier.state.sortByPrice, 'desc');
      sorted = notifier.state.sortedItems;
      expect(sorted[0].itemName, 'Bola Basket'); // Price 150000
      expect(sorted[1].itemName, 'Bola Lampu'); // Price 15000
    });
  });

  group('generateSKUFromName Helper Tests', () {
    test('Correctly generates SKU for Buku Tulis Sinar Dunia Isi 32 Ecer', () {
      final name = 'Buku Tulis Sinar Dunia Isi 32 Ecer';
      final sku = generateSKUFromName(name);
      expect(sku, 'BKTLSSNRD32E');
    });

    test('Correctly generates SKU for Buku Tulis Sinar Dunia Isi 32 Pak', () {
      final name = 'Buku Tulis Sinar Dunia Isi 32 Pak';
      final sku = generateSKUFromName(name);
      expect(sku, 'BKTLSSNRD32P');
    });

    test('Correctly generates SKU for Kopi Kapal Api Saset', () {
      final name = 'Kopi Kapal Api Saset';
      final sku = generateSKUFromName(name);
      expect(sku, 'KPKPLAPS');
    });

    test('Correctly handles empty and special character names', () {
      expect(generateSKUFromName(''), '');
      expect(generateSKUFromName('Aqua Pcs'), 'AQE');
    });
  });
}
