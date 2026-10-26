import '../../data/models/sale_model.dart';
import '../../data/models/cash_reconciliation_model.dart';
import '../../data/models/cash_movement_model.dart';

abstract class SalesRepository {
  Future<void> saveSale(SaleModel sale);
  Future<List<SaleModel>> getSalesHistory({DateTime? startDate, DateTime? endDate});
  Future<void> updateSaleStatus(String invoiceNo, String status, {String? reason, String? user});
  Future<void> saveCashReconciliation(CashReconciliationModel reconciliation);
  Future<List<CashReconciliationModel>> getCashReconciliations();
  Future<List<CashMovementModel>> getCashMovements({DateTime? startDate, DateTime? endDate, int? limit, int? offset});
  Future<CashMovementModel> saveCashMovement(CashMovementModel movement);
  Future<void> deleteCashMovement(String id);
}
