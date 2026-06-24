import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/category_model.dart';
import '../../data/models/item_model.dart';
import '../../domain/repositories/items_repository.dart';
import 'settings_provider.dart';

class ItemsState {
  final List<CategoryModel> categories;
  final List<ItemModel> items;
  final int? selectedCategoryId;
  final String searchQuery;
  final int page;
  final bool isLoading;
  final bool hasReachedMax;
  final String? errorMessage;

  ItemsState({
    this.categories = const [],
    this.items = const [],
    this.selectedCategoryId,
    this.searchQuery = '',
    this.page = 1,
    this.isLoading = false,
    this.hasReachedMax = false,
    this.errorMessage,
  });

  ItemsState copyWith({
    List<CategoryModel>? categories,
    List<ItemModel>? items,
    int? selectedCategoryId,
    bool clearCategory = false,
    String? searchQuery,
    int? page,
    bool? isLoading,
    bool? hasReachedMax,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ItemsState(
      categories: categories ?? this.categories,
      items: items ?? this.items,
      selectedCategoryId: clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ItemsNotifier extends StateNotifier<ItemsState> {
  final ItemsRepository _itemsRepository;

  ItemsNotifier(this._itemsRepository) : super(ItemsState()) {
    initCatalog();
  }

  Future<void> initCatalog() async {
    await loadCategories();
    await loadItems(refresh: true);
  }

  Future<void> loadCategories() async {
    try {
      final list = await _itemsRepository.getCategories();
      state = state.copyWith(categories: list);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal memuat kategori: $e');
    }
  }

  Future<void> loadItems({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && state.hasReachedMax) return;

    final targetPage = refresh ? 1 : state.page + 1;
    state = state.copyWith(isLoading: true, errorMessage: null, clearError: true);

    try {
      List<ItemModel> fetchedItems = [];
      const limit = 50;

      if (state.selectedCategoryId != null) {
        fetchedItems = await _itemsRepository.getItemsByCategory(
          state.selectedCategoryId!,
          page: targetPage,
          limit: limit,
        );
      } else if (state.searchQuery.isNotEmpty) {
        fetchedItems = await _itemsRepository.searchItems(
          state.searchQuery,
          page: targetPage,
          limit: limit,
        );
      } else {
        fetchedItems = await _itemsRepository.getItems(
          page: targetPage,
          limit: limit,
        );
      }

      state = state.copyWith(
        items: refresh ? fetchedItems : [...state.items, ...fetchedItems],
        page: targetPage,
        isLoading: false,
        hasReachedMax: fetchedItems.length < limit,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat produk: $e',
      );
    }
  }

  Future<void> selectCategory(int? categoryId) async {
    if (state.selectedCategoryId == categoryId) return;
    if (categoryId == null) {
      state = state.copyWith(clearCategory: true, searchQuery: '');
    } else {
      state = state.copyWith(selectedCategoryId: categoryId, searchQuery: '');
    }
    await loadItems(refresh: true);
  }

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query, clearCategory: true);
    await loadItems(refresh: true);
  }

  Future<ItemModel?> fetchItemByBarcode(String barcode) async {
    // Attempt search locally in items cache first
    for (var item in state.items) {
      if (item.itemUPC == barcode || item.itemNo == barcode) {
        return item;
      }
    }
    // If not in cache, query API directly
    try {
      final item = await _itemsRepository.getItemByNo(barcode);
      return item;
    } catch (_) {
      return null;
    }
  }
}

final itemsNotifierProvider = StateNotifierProvider<ItemsNotifier, ItemsState>((ref) {
  final repo = ref.watch(itemsRepositoryProvider);
  return ItemsNotifier(repo);
});
