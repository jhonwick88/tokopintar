import '../../domain/repositories/items_repository.dart';
import '../datasources/api_client.dart';
import '../models/category_model.dart';
import '../models/item_model.dart';

class ItemsRepositoryImpl implements ItemsRepository {
  final ApiClient _apiClient;

  ItemsRepositoryImpl(this._apiClient);

  @override
  Future<List<CategoryModel>> getCategories() {
    return _apiClient.getCategories();
  }

  @override
  Future<List<ItemModel>> getItems({required int page, int limit = 50}) {
    return _apiClient.getItems(page: page, limit: limit);
  }

  @override
  Future<ItemModel?> getItemByNo(String itemNo) {
    return _apiClient.getItemByNo(itemNo);
  }

  @override
  Future<List<ItemModel>> searchItems(String query, {required int page, int limit = 50}) {
    return _apiClient.searchItems(query, page: page, limit: limit);
  }

  @override
  Future<List<ItemModel>> getItemsByCategory(int categoryId, {required int page, int limit = 50}) {
    return _apiClient.getItemsByCategory(categoryId, page: page, limit: limit);
  }

  @override
  Future<ItemModel> updateItemKeys({
    required String originalItemNo,
    required String newItemNo,
    required String itemUPC,
    required double price,
    required String itemName,
  }) {
    return _apiClient.updateItemKeys(
      originalItemNo: originalItemNo,
      newItemNo: newItemNo,
      itemUPC: itemUPC,
      price: price,
      itemName: itemName,
    );
  }

  @override
  Future<ItemModel> createItem({
    required String itemNo,
    required String itemName,
    required String itemUPC,
    required int categoryId,
    required double price,
    required double obQuantity,
  }) {
    return _apiClient.createItem(
      itemNo: itemNo,
      itemName: itemName,
      itemUPC: itemUPC,
      categoryId: categoryId,
      price: price,
      obQuantity: obQuantity,
    );
  }
}
