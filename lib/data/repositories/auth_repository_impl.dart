import '../../domain/repositories/auth_repository.dart';
import '../datasources/api_client.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;

  AuthRepositoryImpl(this._apiClient);

  @override
  Future<UserModel?> verifyUserPIN(String pin) async {
    final users = await _apiClient.getUsers();
    try {
      return users.firstWhere((user) => user.pin == pin && user.isActive);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<UserModel>> getUsers() {
    return _apiClient.getUsers();
  }

  @override
  Future<void> saveUser(UserModel user) {
    return _apiClient.saveUser(user);
  }
}
