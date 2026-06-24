import '../../domain/repositories/audit_repository.dart';
import '../datasources/firestore_client.dart';
import '../models/audit_log_model.dart';

class AuditRepositoryImpl implements AuditRepository {
  final FirestoreClient _firestoreClient;

  AuditRepositoryImpl(this._firestoreClient);

  @override
  Future<void> logActivity(String userId, String username, String action, String details) {
    return _firestoreClient.logActivity(userId, username, action, details);
  }

  @override
  Future<List<AuditLogModel>> getAuditLogs() {
    return _firestoreClient.getAuditLogs();
  }
}
