import 'package:dio/dio.dart';
import '../../domain/repositories/categories_repository.dart';
import '../models/category_model.dart';
import '../datasources/api_client.dart';

class CategoriesRepositoryImpl implements CategoriesRepository {
  final ApiClient _apiClient;

  CategoriesRepositoryImpl(this._apiClient);

  @override
  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await _apiClient.dio.get('/api/categories');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => CategoryModel.fromJson(json)).toList();
      } else {
        throw Exception(response.data['message'] ?? 'Failed to load categories');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? e.message ?? 'Network error');
    }
  }

  @override
  Future<CategoryModel> createCategory(CategoryModel category) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/categories',
        data: category.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return CategoryModel.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'Failed to create category');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? e.message ?? 'Network error');
    }
  }

  @override
  Future<CategoryModel> updateCategory(CategoryModel category) async {
    try {
      final response = await _apiClient.dio.put(
        '/api/categories/${category.id}',
        data: category.toJson(),
      );
      if (response.statusCode == 200) {
        return CategoryModel.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'Failed to update category');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? e.message ?? 'Network error');
    }
  }

  @override
  Future<void> deleteCategory(int id) async {
    try {
      final response = await _apiClient.dio.delete('/api/categories/$id');
      if (response.statusCode != 200) {
        throw Exception(response.data['message'] ?? 'Failed to delete category');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? e.message ?? 'Network error');
    }
  }
}
