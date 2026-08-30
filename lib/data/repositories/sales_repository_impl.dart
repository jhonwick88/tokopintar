import '../../domain/repositories/sales_repository.dart';
import '../datasources/api_client.dart';
import '../models/sale_model.dart';
import '../models/cash_reconciliation_model.dart';

class SalesRepositoryImpl implements SalesRepository {
  final ApiClient _apiClient;

  SalesRepositoryImpl(this._apiClient);

  @override
  Future<void> saveSale(SaleModel sale) {
    return _apiClient.saveSale(sale);
  }

  @override
  Future<List<SaleModel>> getSalesHistory({DateTime? startDate, DateTime? endDate}) {
    return _apiClient.getSalesHistory(
      startDate: startDate?.toIso8601String(),
      endDate: endDate?.toIso8601String(),
    );
  }

  @override
  Future<void> updateSaleStatus(String invoiceNo, String status, {String? reason, String? user}) {
    return _apiClient.updateSaleStatus(invoiceNo, status, reason: reason, user: user);
  }

  @override
  Future<void> saveCashReconciliation(CashReconciliationModel reconciliation) {
    return _apiClient.saveCashReconciliation(reconciliation);
  }

  @override
  Future<List<CashReconciliationModel>> getCashReconciliations() {
    return _apiClient.getCashReconciliations();
  }
}
