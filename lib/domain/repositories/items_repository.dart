import '../../data/models/category_model.dart';
import '../../data/models/item_model.dart';

abstract class ItemsRepository {
  Future<List<CategoryModel>> getCategories();
  Future<List<ItemModel>> getItems({required int page, int limit = 50});
  Future<ItemModel?> getItemByNo(String itemNo);
  Future<List<ItemModel>> searchItems(String query, {required int page, int limit = 50});
  Future<List<ItemModel>> getItemsByCategory(int categoryId, {required int page, int limit = 50});
  Future<ItemModel> updateItem(String originalItemNo, ItemModel item);
  Future<ItemModel> createItem(ItemModel item);
  Future<void> deleteItem(String itemNo);
  Future<void> updateStock(String itemNo, double obQuantity, {String? notes});
  Future<List<ItemModel>> getItemsByBarcode(String barcode);
}
