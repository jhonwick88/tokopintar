import '../../data/models/sale_model.dart';
import '../../data/models/cash_reconciliation_model.dart';

abstract class SalesRepository {
  Future<void> saveSale(SaleModel sale);
  Future<List<SaleModel>> getSalesHistory({DateTime? startDate, DateTime? endDate});
  Future<void> updateSaleStatus(String invoiceNo, String status, {String? reason, String? user});
  Future<void> saveCashReconciliation(CashReconciliationModel reconciliation);
  Future<List<CashReconciliationModel>> getCashReconciliations();
}
