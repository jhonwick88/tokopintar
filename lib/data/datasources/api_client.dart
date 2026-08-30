import 'package:dio/dio.dart';
import 'dart:developer' as dev;
import '../models/category_model.dart';
import '../models/item_model.dart';
import '../models/sale_model.dart';
import '../models/cash_reconciliation_model.dart';
import '../models/audit_log_model.dart';
import '../models/quick_item_model.dart';
import '../models/user_model.dart';
import '../models/settings_model.dart';

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
    required String itemName,
  }) async {
    try {
      final response = await _dio.put('/api/items/$originalItemNo', data: {
        'new_itemno': newItemNo,
        'itemupc': itemUPC,
        'price': price,
        'itemname': itemName,
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
        'itemupc': itemUPC,
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

  // --- Sales ---

  Future<List<SaleModel>> getSalesHistory({String? startDate, String? endDate}) async {
    try {
      final queryParams = <String, dynamic>{'limit': '999999'}; // Bypass pagination for accurate summary
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _dio.get('/api/sales', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data != null) {
        final success = response.data['success'] as bool? ?? false;
        if (success) {
          final list = response.data['data'] as List?;
          if (list != null) {
            return list.map((e) => SaleModel.fromJson(e as Map<String, dynamic>)).toList();
          }
        }
      }
      return [];
    } catch (e) {
      dev.log('Error in getSalesHistory: $e');
      rethrow;
    }
  }

  Future<void> saveSale(SaleModel sale) async {
    try {
      final response = await _dio.post('/api/sales', data: sale.toJson());
      if (response.statusCode != 200) {
        throw Exception(response.data?['message'] ?? 'Gagal menyimpan transaksi');
      }
    } catch (e) {
      dev.log('Error in saveSale: $e');
      rethrow;
    }
  }

  Future<void> updateSaleStatus(String invoiceNo, String status, {String? reason, String? user}) async {
    try {
      final response = await _dio.patch(
        '/api/sales/$invoiceNo/status',
        data: {
          'status': status,
          if (reason != null) 'reason': reason,
          if (user != null) 'user': user,
        },
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update sale status');
      }
    } catch (e) {
      dev.log('Error in updateSaleStatus: $e');
      rethrow;
    }
  }

  // --- Cash Reconciliations ---

  Future<List<CashReconciliationModel>> getCashReconciliations() async {
    try {
      final response = await _dio.get('/api/cash-reconciliations', queryParameters: {'limit': '999999'}); // Bypass pagination for accurate summary
      if (response.statusCode == 200 && response.data != null) {
        final success = response.data['success'] as bool? ?? false;
        if (success) {
          final list = response.data['data'] as List?;
          if (list != null) {
            return list.map((e) => CashReconciliationModel.fromJson(e as Map<String, dynamic>)).toList();
          }
        }
      }
      return [];
    } catch (e) {
      dev.log('Error in getCashReconciliations: $e');
      rethrow;
    }
  }

  Future<void> saveCashReconciliation(CashReconciliationModel reconciliation) async {
    try {
      final response = await _dio.post('/api/cash-reconciliations', data: reconciliation.toJson());
      if (response.statusCode != 200) {
        throw Exception(response.data?['message'] ?? 'Gagal menyimpan laporan tutup kasir');
      }
    } catch (e) {
      dev.log('Error in saveCashReconciliation: $e');
      rethrow;
    }
  }

  // --- Audit Logs ---

  Future<List<AuditLogModel>> getAuditLogs() async {
    try {
      final response = await _dio.get('/api/audit-logs');
      if (response.statusCode == 200 && response.data != null) {
        final success = response.data['success'] as bool? ?? false;
        if (success) {
          final list = response.data['data'] as List?;
          if (list != null) {
            return list.map((e) => AuditLogModel.fromJson(e as Map<String, dynamic>)).toList();
          }
        }
      }
      return [];
    } catch (e) {
      dev.log('Error in getAuditLogs: $e');
      rethrow;
    }
  }

  Future<void> logActivity(AuditLogModel logModel) async {
    try {
      final response = await _dio.post('/api/audit-logs', data: logModel.toJson());
      if (response.statusCode != 200) {
        throw Exception(response.data?['message'] ?? 'Gagal menyimpan log audit');
      }
    } catch (e) {
      dev.log('Error in logActivity: $e');
      rethrow;
    }
  }

  // --- Quick Items ---

  Future<List<QuickItemModel>> getQuickItems() async {
    try {
      final response = await _dio.get('/api/quick-items');
      if (response.statusCode == 200 && response.data != null) {
        final success = response.data['success'] as bool? ?? false;
        if (success) {
          final list = response.data['data'] as List?;
          if (list != null) {
            return list.map((e) => QuickItemModel.fromJson(e as Map<String, dynamic>)).toList();
          }
        }
      }
      return [];
    } catch (e) {
      dev.log('Error in getQuickItems: $e');
      rethrow;
    }
  }

  Future<void> saveQuickItem(QuickItemModel item) async {
    try {
      final response = await _dio.post('/api/quick-items', data: item.toJson());
      if (response.statusCode != 200) {
        throw Exception(response.data?['message'] ?? 'Gagal menyimpan quick item');
      }
    } catch (e) {
      dev.log('Error in saveQuickItem: $e');
      rethrow;
    }
  }

  // --- Users ---

  Future<List<UserModel>> getUsers() async {
    try {
      final response = await _dio.get('/api/users');
      if (response.statusCode == 200 && response.data != null) {
        final success = response.data['success'] as bool? ?? false;
        if (success) {
          final list = response.data['data'] as List?;
          if (list != null) {
            return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
          }
        }
      }
      return [];
    } catch (e) {
      dev.log('Error in getUsers: $e');
      rethrow;
    }
  }

  Future<void> saveUser(UserModel user) async {
    try {
      final response = await _dio.post('/api/users', data: user.toJson());
      if (response.statusCode != 200) {
        throw Exception(response.data?['message'] ?? 'Gagal menyimpan user');
      }
    } catch (e) {
      dev.log('Error in saveUser: $e');
      rethrow;
    }
  }

  // --- Settings / Company ---

  Future<SettingsModel> getCompanySettings() async {
    try {
      final response = await _dio.get('/api/company');
      if (response.statusCode == 200 && response.data != null) {
        final success = response.data['success'] as bool? ?? false;
        if (success) {
          final data = response.data['data'];
          if (data != null && data is Map<String, dynamic>) {
            return SettingsModel.fromJson(data);
          }
        }
      }
      return SettingsModel(); // Return defaults if failed
    } catch (e) {
      dev.log('Error in getCompanySettings: $e');
      return SettingsModel(); // Return defaults on error
    }
  }

  Future<void> updateCompanySettings(SettingsModel settings) async {
    try {
      final response = await _dio.put('/api/company', data: settings.toJson());
      if (response.statusCode != 200) {
        throw Exception(response.data?['message'] ?? 'Gagal menyimpan data perusahaan');
      }
    } catch (e) {
      dev.log('Error in updateCompanySettings: $e');
      rethrow;
    }
  }
  // ================= SYSTEM (BACKUP/RESTORE) =================

  Future<void> downloadBackup(String savePath) async {
    try {
      await _dio.download('/api/backup', savePath);
    } on DioException catch (e) {
      dev.log('API Error: ');
    }
  }

  Future<String> restoreBackup(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'database': await MultipartFile.fromFile(filePath, filename: 'toko_pintar.db'),
      });
      final response = await _dio.post('/api/restore', data: formData);
      return response.data['message'] ?? 'Restore berhasil';
    } on DioException catch (e) {
      dev.log('API Error: ');
      throw Exception('Gagal melakukan restore');
    }
  }
}
