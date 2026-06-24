import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import 'settings_provider.dart';

class AuthState {
  final UserModel? currentUser;
  final String? errorMessage;
  final bool isLoading;

  AuthState({
    this.currentUser,
    this.errorMessage,
    this.isLoading = false,
  });

  AuthState copyWith({
    UserModel? currentUser,
    String? errorMessage,
    bool? isLoading,
    bool clearError = false,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final Ref _ref;

  AuthNotifier(this._authRepository, this._ref) : super(AuthState());

  Future<bool> login(String pin) async {
    state = state.copyWith(isLoading: true, errorMessage: null, clearError: true);
    try {
      final user = await _authRepository.verifyUserPIN(pin);
      if (user != null) {
        state = AuthState(currentUser: user, isLoading: false);
        // Log activity
        await _ref.read(auditRepositoryProvider).logActivity(
              user.uid,
              user.username,
              'login',
              'User ${user.fullname} logged in successfully with role ${user.role}',
            );
        return true;
      } else {
        state = AuthState(errorMessage: 'PIN Salah', isLoading: false);
        return false;
      }
    } catch (e) {
      state = AuthState(errorMessage: 'Gagal login: $e', isLoading: false);
      return false;
    }
  }

  Future<void> logout() async {
    final user = state.currentUser;
    if (user != null) {
      // Log activity
      await _ref.read(auditRepositoryProvider).logActivity(
            user.uid,
            user.username,
            'logout',
            'User ${user.fullname} logged out',
          );
    }
    state = AuthState();
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo, ref);
});
