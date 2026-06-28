import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/quick_item_model.dart';
import '../../data/repositories/quick_items_repository_impl.dart';
import '../../domain/repositories/quick_items_repository.dart';
import 'settings_provider.dart';

final quickItemsRepositoryProvider = Provider<QuickItemsRepository>((ref) {
  final client = ref.watch(firestoreClientProvider);
  return QuickItemsRepositoryImpl(client);
});

class QuickItemsNotifier extends StateNotifier<List<QuickItemModel>> {
  final QuickItemsRepository _repository;

  QuickItemsNotifier(this._repository) : super([]) {
    loadQuickItems();
  }

  Future<void> loadQuickItems() async {
    try {
      final list = await _repository.getQuickItems();
      state = list;
    } catch (_) {
      // Fallback local memory values already set
    }
  }

  Future<void> addQuickItem(QuickItemModel item) async {
    final updated = [...state, item];
    state = updated;
    await _repository.saveQuickItem(item);
  }

  Future<void> updateQuickItem(QuickItemModel item) async {
    state = [
      for (final q in state)
        if (q.id == item.id) item else q
    ];
    await _repository.saveQuickItem(item);
  }

  Future<void> deleteQuickItem(String id) async {
    state = state.where((q) => q.id != id).toList();
    await _repository.deleteQuickItem(id);
    await _resequenceQuickItems(state);
  }

  Future<void> reorderQuickItems(int oldIndex, int newIndex) async {
    final list = List<QuickItemModel>.from(state);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final QuickItemModel item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await _resequenceQuickItems(list);
  }

  Future<void> _resequenceQuickItems(List<QuickItemModel> rawList) async {
    final sequenced = <QuickItemModel>[];
    for (int i = 0; i < rawList.length; i++) {
      sequenced.add(rawList[i].copyWith(displayOrder: i));
    }
    state = sequenced;
    await _repository.saveQuickItemsBatch(sequenced);
  }
}

final quickItemsNotifierProvider = StateNotifierProvider<QuickItemsNotifier, List<QuickItemModel>>((ref) {
  final repo = ref.watch(quickItemsRepositoryProvider);
  return QuickItemsNotifier(repo);
});
