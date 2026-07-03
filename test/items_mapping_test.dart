import 'package:flutter_test/flutter_test.dart';
import 'package:tokopintar/data/models/category_model.dart';
import 'package:tokopintar/data/models/item_model.dart';
import 'package:tokopintar/domain/repositories/items_repository.dart';
import 'package:tokopintar/presentation/providers/items_provider.dart';

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
  }) async {
    final idx = db.indexWhere((it) => it.itemNo == originalItemNo);
    if (idx < 0) {
      throw Exception('Not found');
    }
    final existing = db[idx];
    final updated = ItemModel(
      itemNo: newItemNo,
      itemUPC: itemUPC,
      itemName: existing.itemName,
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
  }) async {
    final newItem = ItemModel(
      itemNo: itemNo,
      itemName: itemName,
      itemUPC: itemUPC,
      categoryId: categoryId,
      price: price,
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
      );

      expect(result.itemNo, 'SKU_1_NEW');
      expect(result.itemUPC, '8991111');
      expect(result.itemName, 'Item Satu');

      expect(mockRepo.db.first.itemNo, 'SKU_1_NEW');
      expect(mockRepo.db.first.itemUPC, '8991111');

      final updatedItem = notifier.state.items.firstWhere((it) => it.itemName == 'Item Satu');
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
}
