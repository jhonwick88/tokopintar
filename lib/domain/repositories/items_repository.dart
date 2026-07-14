import '../../data/models/category_model.dart';
import '../../data/models/item_model.dart';

abstract class ItemsRepository {
  Future<List<CategoryModel>> getCategories();
  Future<List<ItemModel>> getItems({required int page, int limit = 50});
  Future<ItemModel?> getItemByNo(String itemNo);
  Future<List<ItemModel>> searchItems(String query, {required int page, int limit = 50});
  Future<List<ItemModel>> getItemsByCategory(int categoryId, {required int page, int limit = 50});
  Future<ItemModel> updateItemKeys({
    required String originalItemNo,
    required String newItemNo,
    required String itemUPC,
    required double price,
    required String itemName,
  });
  Future<ItemModel> createItem({
    required String itemNo,
    required String itemName,
    required String itemUPC,
    required int categoryId,
    required double price,
    required double obQuantity,
  });
}
