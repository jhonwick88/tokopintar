import '../../domain/repositories/auth_repository.dart';
import '../datasources/firestore_client.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirestoreClient _firestoreClient;

  AuthRepositoryImpl(this._firestoreClient);

  @override
  Future<UserModel?> verifyUserPIN(String pin) {
    return _firestoreClient.verifyUserPIN(pin);
  }

  @override
  Future<List<UserModel>> getUsers() {
    return _firestoreClient.getUsers();
  }

  @override
  Future<void> saveUser(UserModel user) {
    return _firestoreClient.saveUser(user);
  }
}
