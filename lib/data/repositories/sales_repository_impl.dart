import '../../domain/repositories/sales_repository.dart';
import '../datasources/firestore_client.dart';
import '../models/sale_model.dart';

class SalesRepositoryImpl implements SalesRepository {
  final FirestoreClient _firestoreClient;

  SalesRepositoryImpl(this._firestoreClient);

  @override
  Future<void> saveSale(SaleModel sale) {
    return _firestoreClient.saveSale(sale);
  }

  @override
  Future<List<SaleModel>> getSalesHistory({DateTime? startDate, DateTime? endDate}) {
    return _firestoreClient.getSalesHistory(startDate: startDate, endDate: endDate);
  }

  @override
  Future<void> updateSaleStatus(String invoiceNo, String status, {String? reason, String? user}) {
    return _firestoreClient.updateSaleStatus(invoiceNo, status, reason: reason, user: user);
  }
}
