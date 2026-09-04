import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/supplier_model.dart';
import '../../domain/repositories/supplier_repository.dart';
import 'settings_provider.dart';

class SupplierState {
  final List<SupplierModel> suppliers;
  final bool isLoading;
  final String? errorMessage;

  SupplierState({
    this.suppliers = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  SupplierState copyWith({
    List<SupplierModel>? suppliers,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SupplierState(
      suppliers: suppliers ?? this.suppliers,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SupplierNotifier extends StateNotifier<SupplierState> {
  final SupplierRepository _repository;

  SupplierNotifier(this._repository) : super(SupplierState()) {
    loadSuppliers();
  }

  Future<void> loadSuppliers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final suppliers = await _repository.getSuppliers();
      state = state.copyWith(suppliers: suppliers, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat data supplier: $e');
    }
  }

  Future<bool> addSupplier(SupplierModel supplier) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final success = await _repository.createSupplier(supplier);
      if (success) {
        await loadSuppliers();
        return true;
      } else {
        state = state.copyWith(isLoading: false, errorMessage: 'Gagal menambah supplier');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Terjadi kesalahan: $e');
      return false;
    }
  }

  Future<bool> updateSupplier(SupplierModel supplier) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final success = await _repository.updateSupplier(supplier);
      if (success) {
        await loadSuppliers();
        return true;
      } else {
        state = state.copyWith(isLoading: false, errorMessage: 'Gagal memperbarui supplier');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Terjadi kesalahan: $e');
      return false;
    }
  }

  Future<bool> deleteSupplier(int id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final success = await _repository.deleteSupplier(id);
      if (success) {
        await loadSuppliers();
        return true;
      } else {
        state = state.copyWith(isLoading: false, errorMessage: 'Gagal menghapus supplier');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Terjadi kesalahan: $e');
      return false;
    }
  }
}

final supplierNotifierProvider = StateNotifierProvider<SupplierNotifier, SupplierState>((ref) {
  final repo = ref.watch(supplierRepositoryProvider);
  return SupplierNotifier(repo);
});
