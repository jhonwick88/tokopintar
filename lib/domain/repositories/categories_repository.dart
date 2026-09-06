import '../../data/models/category_model.dart';

abstract class CategoriesRepository {
  Future<List<CategoryModel>> getCategories();
  Future<CategoryModel> createCategory(CategoryModel category);
  Future<CategoryModel> updateCategory(CategoryModel category);
  Future<void> deleteCategory(int id);
}
