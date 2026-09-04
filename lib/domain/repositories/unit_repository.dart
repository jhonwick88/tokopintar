import '../../data/models/unit_model.dart';

abstract class UnitRepository {
  Future<List<UnitModel>> getUnits();
  Future<UnitModel> createUnit(String name);
  Future<UnitModel> updateUnit(int id, String name);
  Future<void> deleteUnit(int id);
}
