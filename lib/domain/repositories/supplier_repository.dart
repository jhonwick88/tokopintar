import '../../data/models/supplier_model.dart';

abstract class SupplierRepository {
  Future<List<SupplierModel>> getSuppliers();
  Future<bool> createSupplier(SupplierModel supplier);
  Future<bool> updateSupplier(SupplierModel supplier);
  Future<bool> deleteSupplier(int id);
}
