import '../../domain/repositories/unit_repository.dart';
import '../datasources/api_client.dart';
import '../models/unit_model.dart';

class UnitRepositoryImpl implements UnitRepository {
  final ApiClient _apiClient;

  UnitRepositoryImpl(this._apiClient);

  @override
  Future<List<UnitModel>> getUnits() {
    return _apiClient.getUnits();
  }

  @override
  Future<UnitModel> createUnit(String name) {
    return _apiClient.createUnit(name);
  }

  @override
  Future<UnitModel> updateUnit(int id, String name) {
    return _apiClient.updateUnit(id, name);
  }

  @override
  Future<void> deleteUnit(int id) {
    return _apiClient.deleteUnit(id);
  }
}
