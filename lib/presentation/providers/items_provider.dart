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
  final String barcodeFilter; // 'all', 'has_barcode', 'no_barcode'
  final int totalCount;
  final int withBarcodeCount;
  final int withoutBarcodeCount;

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
    this.barcodeFilter = 'all',
    this.totalCount = 0,
    this.withBarcodeCount = 0,
    this.withoutBarcodeCount = 0,
  });

  List<ItemModel> get sortedItems {
    var baseList = items;
    if (barcodeFilter == 'has_barcode') {
      baseList = baseList.where((i) => i.itemUPC.trim().isNotEmpty).toList();
    } else if (barcodeFilter == 'no_barcode') {
      baseList = baseList.where((i) => i.itemUPC.trim().isEmpty).toList();
    }

    if (searchQuery.isEmpty && sortByPrice == 'none') return baseList;
    
    final sorted = List<ItemModel>.from(baseList);
    
    // Split search query into lowercase keywords if present
    final queryWords = searchQuery.isEmpty
        ? <String>[]
        : searchQuery
            .toLowerCase()
            .split(' ')
            .map((w) => w.trim())
            .where((w) => w.isNotEmpty)
            .toList();

    final q = searchQuery.toLowerCase();

    // Helper to determine the sorting priority group of an item
    int getGroupPriority(ItemModel item) {
      if (queryWords.isEmpty) return 0;
      final name = item.itemName.toLowerCase();
      
      // Group 1: Matches exact contiguous query phrase
      if (name.contains(q)) {
        return 1;
      }
      
      // Group 2: Matches all query words but not contiguously
      bool matchesAll = true;
      for (final word in queryWords) {
        if (!name.contains(word)) {
          matchesAll = false;
          break;
        }
      }
      if (matchesAll) {
        return 2;
      }
      
      // Group 3: Partial or other matches
      return 3;
    }

    sorted.sort((a, b) {
      if (queryWords.isNotEmpty) {
        final aPriority = getGroupPriority(a);
        final bPriority = getGroupPriority(b);
        if (aPriority != bPriority) {
          // Lower priority group number comes first (Group 1 before Group 2)
          return aPriority.compareTo(bPriority);
        }
      }
      
      // If same group (or no query), apply price sorting
      if (sortByPrice == 'asc') {
        return a.price.compareTo(b.price);
      } else if (sortByPrice == 'desc') {
        return b.price.compareTo(a.price);
      }
      
      // If sortByPrice is 'none' and they are in the same group, sort by name length (shorter first) then alphabetically
      final aName = a.itemName.toLowerCase();
      final bName = b.itemName.toLowerCase();
      if (aName.length != bName.length) {
        return aName.length.compareTo(bName.length);
      }
      return aName.compareTo(bName);
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
    String? barcodeFilter,
    int? totalCount,
    int? withBarcodeCount,
    int? withoutBarcodeCount,
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
      barcodeFilter: barcodeFilter ?? this.barcodeFilter,
      totalCount: totalCount ?? this.totalCount,
      withBarcodeCount: withBarcodeCount ?? this.withBarcodeCount,
      withoutBarcodeCount: withoutBarcodeCount ?? this.withoutBarcodeCount,
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

  Future<void> setBarcodeFilter(String filter) async {
    if (state.barcodeFilter == filter) return;
    state = state.copyWith(barcodeFilter: filter);
    await loadItems(refresh: true);
  }

  Future<void> loadBarcodeStats() async {
    try {
      final stats = await _itemsRepository.getBarcodeStats();
      state = state.copyWith(
        totalCount: stats['total'] ?? 0,
        withBarcodeCount: stats['with_barcode'] ?? 0,
        withoutBarcodeCount: stats['without_barcode'] ?? 0,
      );
    } catch (_) {}
  }

  Future<void> updateItemBarcode(String itemNo, String barcode, {String? userId, String? username}) async {
    await _itemsRepository.updateItemBarcode(itemNo, barcode, userId: userId, username: username);
    final updated = state.items.map((i) {
      if (i.itemNo == itemNo) {
        return ItemModel(
          itemNo: i.itemNo,
          itemUPC: barcode,
          itemName: i.itemName,
          itemNameShort: i.itemNameShort,
          categoryId: i.categoryId,
          price: i.price,
          obQuantity: i.obQuantity,
          notes: i.notes,
          attribute: i.attribute,
          unit1: i.unit1,
          unit2: i.unit2,
          unit3: i.unit3,
          ratio2: i.ratio2,
          ratio3: i.ratio3,
          defUnitPrice2: i.defUnitPrice2,
          defUnitPrice3: i.defUnitPrice3,
        );
      }
      return i;
    }).toList();
    state = state.copyWith(items: updated);
    await loadBarcodeStats();
  }

  Future<List<ItemModel>> getAllItemsForExport() async {
    final status = state.barcodeFilter != 'all' ? state.barcodeFilter : null;
    return await _itemsRepository.getAllItems(barcodeStatus: status);
  }

  Future<void> clearFiltersAndReload() async {
    state = state.copyWith(searchQuery: '', clearCategory: true, sortByPrice: 'none');
    await loadItems(refresh: true);
  }

  Future<void> initCatalog() async {
    await loadCategories();
    await loadBarcodeStats();
    await clearFiltersAndReload();
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
      final barcodeStatus = state.barcodeFilter != 'all' ? state.barcodeFilter : null;

      if (state.selectedCategoryId != null && state.searchQuery.isNotEmpty) {
        int currentPage = targetPage;
        List<ItemModel> accumulated = [];
        bool reachedEnd = false;

        while (accumulated.length < limit && !reachedEnd) {
          final searchResults = await _performMultiWordSearch(
            state.searchQuery,
            page: currentPage,
            limit: limit,
            barcodeStatus: barcodeStatus,
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
          barcodeStatus: barcodeStatus,
        );
      } else if (state.searchQuery.isNotEmpty) {
        fetchedItems = await _performMultiWordSearch(
          state.searchQuery,
          page: targetPage,
          limit: limit,
          barcodeStatus: barcodeStatus,
        );
      } else {
        fetchedItems = await _itemsRepository.getItems(
          page: targetPage,
          limit: limit,
          barcodeStatus: barcodeStatus,
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

  Future<List<ItemModel>> _performMultiWordSearch(
    String query, {
    required int page,
    required int limit,
    String? barcodeStatus,
  }) async {
    final queryWords = query
        .toLowerCase()
        .split(' ')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();

    if (queryWords.isEmpty) return [];

    final allResults = <ItemModel>[];
    final seenIds = <String>{};

    // If single word, query directly. Otherwise, merge results of all query words.
    if (queryWords.length == 1) {
      try {
        final results = await _itemsRepository.searchItems(
          queryWords[0],
          page: 1,
          limit: limit * 3, // Fetch more to enable local filtering/sorting
          barcodeStatus: barcodeStatus,
        );
        for (final item in results) {
          if (seenIds.add(item.itemNo)) {
            allResults.add(item);
          }
        }
      } catch (e) {
        dev.log('Error searching for single word: $e');
      }
    } else {
      for (final word in queryWords) {
        try {
          final results = await _itemsRepository.searchItems(
            word,
            page: 1,
            limit: limit * 3, // Fetch more to enable local filtering/sorting
            barcodeStatus: barcodeStatus,
          );
          for (final item in results) {
            if (seenIds.add(item.itemNo)) {
              allResults.add(item);
            }
          }
        } catch (e) {
          dev.log('Error searching for word "$word": $e');
        }
      }
    }

    // Filter: MUST contain ALL query words (case-insensitive)
    final filteredResults = <ItemModel>[];
    for (final item in allResults) {
      final name = item.itemName.toLowerCase();
      bool matchesAll = true;
      for (final word in queryWords) {
        if (!name.contains(word)) {
          matchesAll = false;
          break;
        }
      }
      if (matchesAll) {
        filteredResults.add(item);
      }
    }

    // Sort by relevance:
    // 1. Contiguous match (matches exact query phrase)
    // 2. Index of exact match (closer to start of name is better)
    // 3. Length of name (shorter name = tighter match)
    // 4. Alphabetical
    filteredResults.sort((a, b) {
      final aName = a.itemName.toLowerCase();
      final bName = b.itemName.toLowerCase();
      final q = query.toLowerCase();

      final aExact = aName.contains(q);
      final bExact = bName.contains(q);

      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;

      if (aExact && bExact) {
        final aIdx = aName.indexOf(q);
        final bIdx = bName.indexOf(q);
        if (aIdx != bIdx) {
          return aIdx.compareTo(bIdx);
        }
      }

      if (aName.length != bName.length) {
        return aName.length.compareTo(bName.length);
      }

      return aName.compareTo(bName);
    });

    // Local pagination
    final startIndex = (page - 1) * limit;
    if (startIndex < filteredResults.length) {
      return filteredResults.skip(startIndex).take(limit).toList();
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
    final trimmed = query.trim();
    if (state.searchQuery == trimmed) return;
    state = state.copyWith(searchQuery: trimmed, clearCategory: true);
    await loadItems(refresh: true);
  }

  Future<List<ItemModel>> fetchItemsByBarcode(String barcode) async {
    // 1. Try local exact matches first
    final localMatches = state.items.where((item) => item.itemUPC == barcode || item.itemNo == barcode).toList();
    if (localMatches.isNotEmpty) {
      return localMatches;
    }
    
    // 2. Try fetching list by UPC/itemNo from backend
    try {
      final results = await _itemsRepository.getItemsByBarcode(barcode);
      if (results.isNotEmpty) return results;
    } catch (_) {}
    
    return [];
  }

  Future<ItemModel?> fetchItemByBarcode(String barcode) async {
    final results = await fetchItemsByBarcode(barcode);
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<void> deleteItem(String itemNo) async {
    await _itemsRepository.deleteItem(itemNo);
    state = state.copyWith(items: state.items.where((item) => item.itemNo != itemNo).toList());
  }

  Future<void> updateStock(String itemNo, double obQuantity, {String? notes}) async {
    try {
      await _itemsRepository.updateStock(itemNo, obQuantity, notes: notes);
      await loadItems(refresh: true);
    } catch (e) {
      throw Exception('Gagal memperbarui stok: $e');
    }
  }

  Future<ItemModel> updateItem(String originalItemNo, ItemModel item) async {
    final updated = await _itemsRepository.updateItem(originalItemNo, item);

    final updatedList = state.items.map((item) {
      if (item.itemNo == originalItemNo) {
        return updated;
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedList);
    return updated;
  }

  Future<ItemModel> createItem(ItemModel item) async {
    final newItem = await _itemsRepository.createItem(item);

    final newList = [...state.items, newItem];
    state = state.copyWith(items: newList);
    return newItem;
  }
}

final itemsNotifierProvider = StateNotifierProvider<ItemsNotifier, ItemsState>((ref) {
  final repo = ref.watch(itemsRepositoryProvider);
  return ItemsNotifier(repo);
});
