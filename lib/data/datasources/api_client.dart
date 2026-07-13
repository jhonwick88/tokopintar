import 'package:dio/dio.dart';
import 'dart:developer' as dev;
import '../models/category_model.dart';
import '../models/item_model.dart';

class ApiClient {
  final Dio _dio;
  String _baseUrl;

  ApiClient({required String baseUrl})
      : _baseUrl = baseUrl,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        dev.log('API Request: ${options.method} ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        dev.log('API Response [${response.statusCode}]: ${response.data}');
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        dev.log('API Error: ${e.message}', error: e);
        return handler.next(e);
      },
    ));
  }

  void updateBaseUrl(String newUrl) {
    _baseUrl = newUrl;
    _dio.options.baseUrl = newUrl;
  }

  String get baseUrl => _baseUrl;

  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await _dio.get('/api/categories');
      if (response.statusCode == 200 && response.data != null) {
        final success = response.data['success'] as bool? ?? false;
        if (success) {
          final list = response.data['data'] as List?;
          if (list != null) {
            return list.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
          }
        }
      }
      return [];
    } catch (e) {
      dev.log('Error in getCategories: $e');
      rethrow;
    }
  }

  Future<List<ItemModel>> getItems({required int page, int limit = 50}) async {
    try {
      final response = await _dio.get('/api/items', queryParameters: {
        'page': page,
        'limit': limit,
      });
      if (response.statusCode == 200 && response.data != null) {
        final success = response.data['success'] as bool? ?? false;
        if (success) {
          final list = response.data['data'] as List?;
          if (list != null) {
            return list.map((e) => ItemModel.fromJson(e as Map<String, dynamic>)).toList();
          }
        }
      }
      return [];
    } catch (e) {
      dev.log('Error in getItems: $e');
      rethrow;
    }
  }

  Future<ItemModel?> getItemByNo(String itemNo) async {
    try {
      final response = await _dio.get('/api/items/$itemNo');
      if (response.statusCode == 200 && response.data != null) {
        final success = response.data['success'] as bool? ?? false;
        if (success) {
          final data = response.data['data'];
          if (data != null && data is Map<String, dynamic>) {
            return ItemModel.fromJson(data);
          }
        }
      }
      return null;
    } catch (e) {
      dev.log('Error in getItemByNo: $e');
      return null; // Return null if not found
    }
  }

  Future<List<ItemModel>> searchItems(String query, {required int page, int limit = 50}) async {
    try {
      if (query.isEmpty) {
        return getItems(page: page, limit: limit);
      }
      final response = await _dio.get('/api/items/search', queryParameters: {
        'q': query,
        'page': page,
        'limit': limit,
      });
      if (response.statusCode == 200 && response.data != null) {
        final success = response.data['success'] as bool? ?? false;
        if (success) {
          final list = response.data['data'] as List?;
          if (list != null) {
            return list.map((e) => ItemModel.fromJson(e as Map<String, dynamic>)).toList();
          }
        }
      }
      return [];
    } catch (e) {
      dev.log('Error in searchItems: $e');
      rethrow;
    }
  }

  Future<List<ItemModel>> getItemsByCategory(int categoryId, {required int page, int limit = 50}) async {
    try {
      final response = await _dio.get('/api/categories/$categoryId/items', queryParameters: {
        'page': page,
        'limit': limit,
      });
      if (response.statusCode == 200 && response.data != null) {
        final success = response.data['success'] as bool? ?? false;
        if (success) {
          final list = response.data['data'] as List?;
          if (list != null) {
            return list.map((e) => ItemModel.fromJson(e as Map<String, dynamic>)).toList();
          }
        }
      }
      return [];
    } catch (e) {
      dev.log('Error in getItemsByCategory: $e');
      rethrow;
    }
  }

  Future<ItemModel> updateItemKeys({
    required String originalItemNo,
    required String newItemNo,
    required String itemUPC,
    required double price,
  }) async {
    try {
      final response = await _dio.put('/api/items/$originalItemNo', data: {
        'new_itemno': newItemNo,
        'itemupc': itemUPC.trim().isEmpty ? null : itemUPC.trim(),
        'price': price,
      });
      if (response.statusCode == 200 && response.data != null) {
        final success = response.data['success'] as bool? ?? false;
        if (success) {
          final data = response.data['data'];
          if (data != null && data is Map<String, dynamic>) {
            return ItemModel.fromJson(data);
          }
        }
      }
      throw Exception(response.data?['message'] ?? 'Gagal memperbarui barcode dan SKU produk');
    } catch (e) {
      dev.log('Error in updateItemKeys: $e');
      rethrow;
    }
  }

  Future<ItemModel> createItem({
    required String itemNo,
    required String itemName,
    required String itemUPC,
    required int categoryId,
    required double price,
    required double obQuantity,
  }) async {
    try {
      final response = await _dio.post('/api/items', data: {
        'itemno': itemNo,
        'itemname': itemName,
        'itemupc': itemUPC.trim().isEmpty ? null : itemUPC.trim(),
        'categoryid': categoryId,
        'price': price,
        'itemtype': 0,
        'obquantity': obQuantity,
      });
      if (response.statusCode == 200 && response.data != null) {
        final success = response.data['success'] as bool? ?? false;
        if (success) {
          final data = response.data['data'];
          if (data != null && data is Map<String, dynamic>) {
            return ItemModel.fromJson(data);
          }
        }
      }
      throw Exception(response.data?['message'] ?? 'Gagal menambahkan produk baru');
    } catch (e) {
      dev.log('Error in createItem: $e');
      rethrow;
    }
  }
}
