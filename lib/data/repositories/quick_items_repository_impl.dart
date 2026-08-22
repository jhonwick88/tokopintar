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
    // Requires backend DELETE endpoint
    dev.log('deleteQuickItem called but not supported by backend yet: $id');
  }

  @override
  Future<void> saveQuickItemsBatch(List<QuickItemModel> items) async {
    for (var item in items) {
      await _apiClient.saveQuickItem(item);
    }
  }
}
