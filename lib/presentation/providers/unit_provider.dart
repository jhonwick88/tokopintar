import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import '../../data/datasources/api_client.dart';
import '../../data/repositories/unit_repository_impl.dart';
import '../../domain/repositories/unit_repository.dart';
import '../../data/models/unit_model.dart';

final unitRepositoryProvider = Provider<UnitRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return UnitRepositoryImpl(apiClient);
});

final unitsProvider = StateNotifierProvider<UnitsNotifier, AsyncValue<List<UnitModel>>>((ref) {
  final repository = ref.read(unitRepositoryProvider);
  return UnitsNotifier(repository);
});

class UnitsNotifier extends StateNotifier<AsyncValue<List<UnitModel>>> {
  final UnitRepository _repository;

  UnitsNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetchUnits();
  }

  Future<void> fetchUnits() async {
    try {
      state = const AsyncValue.loading();
      final units = await _repository.getUnits();
      state = AsyncValue.data(units);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createUnit(String name) async {
    try {
      final newUnit = await _repository.createUnit(name);
      if (state.hasValue) {
        state = AsyncValue.data([...state.value!, newUnit]);
      } else {
        await fetchUnits();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUnit(int id, String name) async {
    try {
      final updatedUnit = await _repository.updateUnit(id, name);
      if (state.hasValue) {
        final current = state.value!;
        final index = current.indexWhere((u) => u.id == id);
        if (index != -1) {
          final newList = List<UnitModel>.from(current);
          newList[index] = updatedUnit;
          state = AsyncValue.data(newList);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteUnit(int id) async {
    try {
      await _repository.deleteUnit(id);
      if (state.hasValue) {
        final current = state.value!;
        final newList = current.where((u) => u.id != id).toList();
        state = AsyncValue.data(newList);
      }
    } catch (e) {
      rethrow;
    }
  }
}
