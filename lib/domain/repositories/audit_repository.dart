import '../../data/models/audit_log_model.dart';

abstract class AuditRepository {
  Future<void> logActivity(String userId, String username, String action, String details);
  Future<List<AuditLogModel>> getAuditLogs();
}
