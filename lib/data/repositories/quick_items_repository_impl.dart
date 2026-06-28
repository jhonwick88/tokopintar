import '../../domain/repositories/quick_items_repository.dart';
import '../datasources/firestore_client.dart';
import '../models/quick_item_model.dart';

class QuickItemsRepositoryImpl implements QuickItemsRepository {
  final FirestoreClient _firestoreClient;

  QuickItemsRepositoryImpl(this._firestoreClient);

  @override
  Future<List<QuickItemModel>> getQuickItems() {
    return _firestoreClient.getQuickItems();
  }

  @override
  Future<void> saveQuickItem(QuickItemModel item) {
    return _firestoreClient.saveQuickItem(item);
  }

  @override
  Future<void> deleteQuickItem(String id) {
    return _firestoreClient.deleteQuickItem(id);
  }

  @override
  Future<void> saveQuickItemsBatch(List<QuickItemModel> items) {
    return _firestoreClient.saveQuickItemsBatch(items);
  }
}
