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
  Future<ItemModel> updateItem(String originalItemNo, ItemModel item) {
    return _apiClient.updateItem(originalItemNo, item);
  }

  @override
  Future<ItemModel> createItem(ItemModel item) {
    return _apiClient.createItem(item);
  }

  @override
  Future<void> deleteItem(String itemNo) {
    return _apiClient.deleteItem(itemNo);
  }

  @override
  Future<void> updateStock(String itemNo, double obQuantity, {String? notes}) async {
    return await _apiClient.updateStock(itemNo, obQuantity, notes: notes);
  }

  @override
  Future<List<ItemModel>> getItemsByBarcode(String barcode) {
    return _apiClient.getItemsByBarcode(barcode);
  }
}
