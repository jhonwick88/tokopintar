import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import 'settings_provider.dart';

class UsersState {
  final List<UserModel> users;
  final bool isLoading;
  final String? errorMessage;

  UsersState({
    this.users = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  UsersState copyWith({
    List<UserModel>? users,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UsersState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class UsersNotifier extends StateNotifier<UsersState> {
  final AuthRepository _authRepository;

  UsersNotifier(this._authRepository) : super(UsersState()) {
    loadUsers();
  }

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final users = await _authRepository.getUsers();
      state = state.copyWith(users: users, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat daftar pengguna: $e',
      );
    }
  }

  Future<bool> createUser(UserModel user) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authRepository.saveUser(user);
      await loadUsers();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal menambahkan user: $e',
      );
      return false;
    }
  }

  Future<bool> updateUser(UserModel user) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authRepository.updateUser(user);
      await loadUsers();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memperbarui user: $e',
      );
      return false;
    }
  }

  Future<bool> deleteUser(String uid) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authRepository.deleteUser(uid);
      await loadUsers();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal menghapus user: $e',
      );
      return false;
    }
  }
}

final usersNotifierProvider = StateNotifierProvider<UsersNotifier, UsersState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return UsersNotifier(authRepo);
});
