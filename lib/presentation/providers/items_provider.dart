import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as dev;
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
  final String sortByPrice; // 'none', 'asc', 'desc'

  ItemsState({
    this.categories = const [],
    this.items = const [],
    this.selectedCategoryId,
    this.searchQuery = '',
    this.page = 1,
    this.isLoading = false,
    this.hasReachedMax = false,
    this.errorMessage,
    this.sortByPrice = 'none',
  });

  List<ItemModel> get sortedItems {
    if (searchQuery.isEmpty && sortByPrice == 'none') return items;
    
    final sorted = List<ItemModel>.from(items);
    
    // Split search query into lowercase keywords if present
    final queryWords = searchQuery.isEmpty
        ? <String>[]
        : searchQuery
            .toLowerCase()
            .split(' ')
            .map((w) => w.trim())
            .where((w) => w.isNotEmpty)
            .toList();

    int getMatchCount(ItemModel item) {
      if (queryWords.isEmpty) return 0;
      final name = item.itemName.toLowerCase();
      int matches = 0;
      for (final word in queryWords) {
        if (name.contains(word)) {
          matches++;
        }
      }
      return matches;
    }

    sorted.sort((a, b) {
      if (queryWords.isNotEmpty) {
        final aMatches = getMatchCount(a);
        final bMatches = getMatchCount(b);
        if (aMatches != bMatches) {
          // Higher match count comes first
          return bMatches.compareTo(aMatches);
        }
      }
      
      // If match counts are equal (or query is empty), sort by price if specified
      if (sortByPrice == 'asc') {
        return a.price.compareTo(b.price);
      } else if (sortByPrice == 'desc') {
        return b.price.compareTo(a.price);
      }
      
      // If sortByPrice is 'none' and match counts are equal, keep alphabetical
      return a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase());
    });

    return sorted;
  }

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
    String? sortByPrice,
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
      sortByPrice: sortByPrice ?? this.sortByPrice,
    );
  }
}

class ItemsNotifier extends StateNotifier<ItemsState> {
  final ItemsRepository _itemsRepository;

  ItemsNotifier(this._itemsRepository) : super(ItemsState()) {
    initCatalog();
  }

  void toggleSortByPrice(String order) {
    state = state.copyWith(sortByPrice: order);
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

      if (state.selectedCategoryId != null && state.searchQuery.isNotEmpty) {
        int currentPage = targetPage;
        List<ItemModel> accumulated = [];
        bool reachedEnd = false;

        while (accumulated.length < limit && !reachedEnd) {
          final searchResults = await _performMultiWordSearch(
            state.searchQuery,
            page: currentPage,
            limit: limit,
          );
          if (searchResults.isEmpty) {
            reachedEnd = true;
            break;
          }
          final filtered = searchResults
              .where((item) => item.categoryId == state.selectedCategoryId)
              .toList();
          accumulated.addAll(filtered);
          if (searchResults.length < limit) {
            reachedEnd = true;
          } else {
            currentPage++;
          }
        }
        fetchedItems = accumulated;
        state = state.copyWith(
          items: refresh ? fetchedItems : [...state.items, ...fetchedItems],
          page: currentPage,
          isLoading: false,
          hasReachedMax: reachedEnd,
        );
        return;
      } else if (state.selectedCategoryId != null) {
        fetchedItems = await _itemsRepository.getItemsByCategory(
          state.selectedCategoryId!,
          page: targetPage,
          limit: limit,
        );
      } else if (state.searchQuery.isNotEmpty) {
        fetchedItems = await _performMultiWordSearch(
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

  Future<List<ItemModel>> _performMultiWordSearch(String query, {required int page, required int limit}) async {
    final queryWords = query
        .toLowerCase()
        .split(' ')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();

    if (queryWords.isEmpty) return [];

    if (queryWords.length == 1) {
      return await _itemsRepository.searchItems(
        query,
        page: page,
        limit: limit,
      );
    }

    final allResults = <ItemModel>[];
    final seenIds = <String>{};

    for (final word in queryWords) {
      try {
        final results = await _itemsRepository.searchItems(
          word,
          page: 1, // Ambil halaman pertama untuk setiap kata kunci pencarian
          limit: limit * 2, // Ambil lebih banyak produk agar penggabungan lebih relevan
        );
        for (final item in results) {
          final id = item.itemNo;
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            allResults.add(item);
          }
        }
      } catch (e) {
        dev.log('Error searching for word "$word": $e');
      }
    }

    // Urutkan berdasarkan relevansi (berapa banyak kecocokan kata kunci di nama produk)
    allResults.sort((a, b) {
      final aName = a.itemName.toLowerCase();
      final bName = b.itemName.toLowerCase();

      int aMatches = 0;
      int bMatches = 0;
      for (final word in queryWords) {
        if (aName.contains(word)) aMatches++;
        if (bName.contains(word)) bMatches++;
      }

      if (aMatches != bMatches) {
        return bMatches.compareTo(aMatches); // Kecocokan terbanyak berada di atas
      }
      return aName.compareTo(bName); // Jika jumlah kecocokan sama, urutkan berdasarkan abjad
    });

    // Paginasi lokal pada daftar gabungan
    final startIndex = (page - 1) * limit;
    if (startIndex < allResults.length) {
      return allResults.skip(startIndex).take(limit).toList();
    }
    return [];
  }

  Future<void> selectCategory(int? categoryId) async {
    if (state.selectedCategoryId == categoryId) return;
    if (categoryId == null) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategoryId: categoryId);
    }
    await loadItems(refresh: true);
  }

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query, clearCategory: true);
    await loadItems(refresh: true);
  }

  Future<ItemModel?> fetchItemByBarcode(String barcode) async {
    // 1. Check local state cache first
    for (var item in state.items) {
      if (item.itemUPC == barcode || item.itemNo == barcode) {
        return item;
      }
    }
    
    // 2. Try fetching by SKU/itemNo directly
    try {
      final item = await _itemsRepository.getItemByNo(barcode);
      if (item != null) return item;
    } catch (_) {}
    
    // 3. Search database using REST API search endpoint (searches itemUPC, itemNo, itemName)
    try {
      final results = await _itemsRepository.searchItems(barcode, page: 1, limit: 10);
      for (var item in results) {
        if (item.itemUPC == barcode || item.itemNo == barcode) {
          return item;
        }
      }
    } catch (_) {}
    
    return null;
  }

  Future<ItemModel> updateItemKeys({
    required String originalItemNo,
    required String newItemNo,
    required String itemUPC,
    required double price,
    required String itemName,
  }) async {
    final updated = await _itemsRepository.updateItemKeys(
      originalItemNo: originalItemNo,
      newItemNo: newItemNo,
      itemUPC: itemUPC,
      price: price,
      itemName: itemName,
    );

    final updatedList = state.items.map((item) {
      if (item.itemNo == originalItemNo) {
        return updated;
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedList);
    return updated;
  }

  Future<ItemModel> createItem({
    required String itemNo,
    required String itemName,
    required String itemUPC,
    required int categoryId,
    required double price,
    required double obQuantity,
  }) async {
    final newItem = await _itemsRepository.createItem(
      itemNo: itemNo,
      itemName: itemName,
      itemUPC: itemUPC,
      categoryId: categoryId,
      price: price,
      obQuantity: obQuantity,
    );

    final newList = [...state.items, newItem];
    state = state.copyWith(items: newList);
    return newItem;
  }
}

final itemsNotifierProvider = StateNotifierProvider<ItemsNotifier, ItemsState>((ref) {
  final repo = ref.watch(itemsRepositoryProvider);
  return ItemsNotifier(repo);
});
