import '../../domain/repositories/audit_repository.dart';
import '../datasources/api_client.dart';
import '../models/audit_log_model.dart';
import 'package:uuid/uuid.dart';

class AuditRepositoryImpl implements AuditRepository {
  final ApiClient _apiClient;
  final Uuid _uuid = const Uuid();

  AuditRepositoryImpl(this._apiClient);

  @override
  Future<void> logActivity(String userId, String username, String action, String details) {
    final logModel = AuditLogModel(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      userId: userId,
      username: username,
      action: action,
      details: details,
    );
    return _apiClient.logActivity(logModel);
  }

  @override
  Future<List<AuditLogModel>> getAuditLogs() {
    return _apiClient.getAuditLogs();
  }
}
