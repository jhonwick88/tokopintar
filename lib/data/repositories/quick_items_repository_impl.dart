import '../../domain/repositories/quick_items_repository.dart';
import '../datasources/api_client.dart';
import '../models/quick_item_model.dart';
import 'dart:developer' as dev;

class QuickItemsRepositoryImpl implements QuickItemsRepository {
  final ApiClient _apiClient;

  QuickItemsRepositoryImpl(this._apiClient);

  @override
  Future<List<QuickItemModel>> getQuickItems() {
    return _apiClient.getQuickItems();
  }

  @override
  Future<void> saveQuickItem(QuickItemModel item) {
    return _apiClient.saveQuickItem(item);
  }

  @override
  Future<void> deleteQuickItem(String id) async {
    try {
      await _apiClient.deleteQuickItem(id);
    } catch (e) {
      dev.log('Error deleting quick item from backend: $e');
    }
  }

  @override
  Future<void> saveQuickItemsBatch(List<QuickItemModel> items) async {
    try {
      await _apiClient.saveQuickItemsBatch(items);
    } catch (e) {
      // Fallback one-by-one if batch route not supported
      for (var item in items) {
        try {
          await _apiClient.saveQuickItem(item);
        } catch (_) {}
      }
    }
  }
}
