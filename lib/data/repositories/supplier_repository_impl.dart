import '../../domain/repositories/supplier_repository.dart';
import '../datasources/api_client.dart';
import '../models/supplier_model.dart';

class SupplierRepositoryImpl implements SupplierRepository {
  final ApiClient _apiClient;

  SupplierRepositoryImpl(this._apiClient);

  @override
  Future<List<SupplierModel>> getSuppliers() async {
    return await _apiClient.getSuppliers();
  }

  @override
  Future<bool> createSupplier(SupplierModel supplier) async {
    return await _apiClient.createSupplier(supplier);
  }

  @override
  Future<bool> updateSupplier(SupplierModel supplier) async {
    return await _apiClient.updateSupplier(supplier);
  }

  @override
  Future<bool> deleteSupplier(int id) async {
    return await _apiClient.deleteSupplier(id);
  }
}
