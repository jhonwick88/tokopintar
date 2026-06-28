import '../../data/models/quick_item_model.dart';

abstract class QuickItemsRepository {
  Future<List<QuickItemModel>> getQuickItems();
  Future<void> saveQuickItem(QuickItemModel item);
  Future<void> deleteQuickItem(String id);
  Future<void> saveQuickItemsBatch(List<QuickItemModel> items);
}
