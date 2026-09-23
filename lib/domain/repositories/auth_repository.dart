import '../../data/models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel?> verifyUserPIN(String pin);
  Future<List<UserModel>> getUsers();
  Future<void> saveUser(UserModel user);
  Future<void> updateUser(UserModel user);
  Future<void> deleteUser(String uid);
}
