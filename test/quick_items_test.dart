import 'package:flutter_test/flutter_test.dart';
import 'package:tokopintar/data/models/quick_item_model.dart';
import 'package:tokopintar/domain/repositories/quick_items_repository.dart';
import 'package:tokopintar/presentation/providers/quick_items_provider.dart';

class MockQuickItemsRepository implements QuickItemsRepository {
  List<QuickItemModel> db = [];

  @override
  Future<List<QuickItemModel>> getQuickItems() async {
    return db;
  }

  @override
  Future<void> saveQuickItem(QuickItemModel item) async {
    final idx = db.indexWhere((q) => q.id == item.id);
    if (idx >= 0) {
      db[idx] = item;
    } else {
      db.add(item);
    }
  }

  @override
  Future<void> deleteQuickItem(String id) async {
    db.removeWhere((q) => q.id == id);
  }

  @override
  Future<void> saveQuickItemsBatch(List<QuickItemModel> items) async {
    for (var item in items) {
      await saveQuickItem(item);
    }
  }
}

void main() {
  group('QuickItemModel Tests', () {
    test('JSON serialization & deserialization', () {
      final model = QuickItemModel(
        id: 'q_1',
        itemNo: 'it_100',
        itemName: 'Fotokopi',
        iconName: 'description',
        colorHex: '0xff4caf50',
        displayOrder: 1,
        isActive: true,
      );

      final json = model.toJson();
      expect(json['id'], 'q_1');
      expect(json['item_no'], 'it_100');
      expect(json['item_name'], 'Fotokopi');
      expect(json['icon_name'], 'description');
      expect(json['color_hex'], '0xff4caf50');
      expect(json['display_order'], 1);
      expect(json['is_active'], true);

      final parsed = QuickItemModel.fromJson(json);
      expect(parsed.id, 'q_1');
      expect(parsed.itemNo, 'it_100');
      expect(parsed.itemName, 'Fotokopi');
      expect(parsed.iconName, 'description');
      expect(parsed.colorHex, '0xff4caf50');
      expect(parsed.displayOrder, 1);
      expect(parsed.isActive, true);
    });
  });

  group('QuickItemsNotifier Tests', () {
    late MockQuickItemsRepository mockRepo;
    late QuickItemsNotifier notifier;

    setUp(() {
      mockRepo = MockQuickItemsRepository();
      notifier = QuickItemsNotifier(mockRepo);
    });

    test('Add Quick Items adds and stores item', () async {
      final shortcut = QuickItemModel(id: '1', itemNo: 'itemA', itemName: 'Print', displayOrder: 0);
      await notifier.addQuickItem(shortcut);

      expect(notifier.state.length, 1);
      expect(notifier.state.first.itemName, 'Print');
      expect(mockRepo.db.length, 1);
    });

    test('Update Quick Item updates details', () async {
      final shortcut = QuickItemModel(id: '1', itemNo: 'itemA', itemName: 'Print', displayOrder: 0);
      await notifier.addQuickItem(shortcut);

      final updated = shortcut.copyWith(itemName: 'Print A4');
      await notifier.updateQuickItem(updated);

      expect(notifier.state.first.itemName, 'Print A4');
      expect(mockRepo.db.first.itemName, 'Print A4');
    });

    test('Delete Quick Item and resequence display order', () async {
      final s1 = QuickItemModel(id: '1', itemNo: 'itemA', itemName: 'A', displayOrder: 0);
      final s2 = QuickItemModel(id: '2', itemNo: 'itemB', itemName: 'B', displayOrder: 1);
      final s3 = QuickItemModel(id: '3', itemNo: 'itemC', itemName: 'C', displayOrder: 2);

      await notifier.addQuickItem(s1);
      await notifier.addQuickItem(s2);
      await notifier.addQuickItem(s3);

      expect(notifier.state.length, 3);

      await notifier.deleteQuickItem('2');

      expect(notifier.state.length, 2);
      expect(notifier.state[0].id, '1');
      expect(notifier.state[0].displayOrder, 0);
      expect(notifier.state[1].id, '3');
      expect(notifier.state[1].displayOrder, 1); // Sequenced index updated!
    });

    test('Reorder Quick Items list sequence reordering', () async {
      final s1 = QuickItemModel(id: '1', itemNo: 'itemA', itemName: 'A', displayOrder: 0);
      final s2 = QuickItemModel(id: '2', itemNo: 'itemB', itemName: 'B', displayOrder: 1);
      final s3 = QuickItemModel(id: '3', itemNo: 'itemC', itemName: 'C', displayOrder: 2);

      await notifier.addQuickItem(s1);
      await notifier.addQuickItem(s2);
      await notifier.addQuickItem(s3);

      // Reorder: Move A (index 0) to after B (index 1 -> newIndex 2 in drag-drop logic)
      await notifier.reorderQuickItems(0, 2);

      expect(notifier.state[0].id, '2');
      expect(notifier.state[0].displayOrder, 0);
      
      expect(notifier.state[1].id, '1');
      expect(notifier.state[1].displayOrder, 1);
      
      expect(notifier.state[2].id, '3');
      expect(notifier.state[2].displayOrder, 2);
    });
  });
}
