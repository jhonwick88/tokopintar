import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/api_client.dart';
import '../../data/repositories/categories_repository_impl.dart';
import '../../domain/repositories/categories_repository.dart';
import '../../data/models/category_model.dart';
import 'settings_provider.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CategoriesRepositoryImpl(apiClient);
});

class CategoriesState {
  final bool isLoading;
  final String? error;
  final List<CategoryModel> categories;

  CategoriesState({
    this.isLoading = false,
    this.error,
    this.categories = const [],
  });

  CategoriesState copyWith({
    bool? isLoading,
    String? error,
    List<CategoryModel>? categories,
  }) {
    return CategoriesState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      categories: categories ?? this.categories,
    );
  }
}

class CategoriesNotifier extends StateNotifier<CategoriesState> {
  final CategoriesRepository _repository;

  CategoriesNotifier(this._repository) : super(CategoriesState()) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final categories = await _repository.getCategories();
      state = state.copyWith(isLoading: false, categories: categories);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createCategory(CategoryModel category) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final newCategory = await _repository.createCategory(category);
      state = state.copyWith(
        isLoading: false,
        categories: [...state.categories, newCategory]..sort((a, b) => a.name.compareTo(b.name)),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateCategory(CategoryModel category) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedCategory = await _repository.updateCategory(category);
      final updatedList = state.categories.map((c) {
        return c.id == updatedCategory.id ? updatedCategory : c;
      }).toList();
      updatedList.sort((a, b) => a.name.compareTo(b.name));
      
      state = state.copyWith(
        isLoading: false,
        categories: updatedList,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteCategory(int id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.deleteCategory(id);
      state = state.copyWith(
        isLoading: false,
        categories: state.categories.where((c) => c.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final categoriesProvider = StateNotifierProvider<CategoriesNotifier, CategoriesState>((ref) {
  final repository = ref.watch(categoriesRepositoryProvider);
  return CategoriesNotifier(repository);
});
