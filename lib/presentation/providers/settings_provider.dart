import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/api_client.dart';
import '../../data/datasources/firestore_client.dart';
import '../../data/models/settings_model.dart';
import '../../data/repositories/audit_repository_impl.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/items_repository_impl.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/repositories/audit_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/items_repository.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/repositories/settings_repository.dart';

// --- DATA SOURCE PROVIDERS ---
final firestoreClientProvider = Provider<FirestoreClient>((ref) {
  return FirestoreClient();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return ApiClient(baseUrl: settings.restApiUrl);
});

// --- REPOSITORY PROVIDERS ---
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(firestoreClientProvider));
});

final itemsRepositoryProvider = Provider<ItemsRepository>((ref) {
  return ItemsRepositoryImpl(ref.watch(apiClientProvider));
});

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepositoryImpl(ref.watch(firestoreClientProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl(ref.watch(firestoreClientProvider));
});

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  return AuditRepositoryImpl(ref.watch(firestoreClientProvider));
});

// --- SETTINGS NOTIFIER ---
class SettingsNotifier extends StateNotifier<SettingsModel> {
  final SettingsRepository _settingsRepository;

  SettingsNotifier(this._settingsRepository) : super(SettingsModel()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final settings = await _settingsRepository.getSettings();
      state = settings;
    } catch (_) {
      // Keep defaults
    }
  }

  Future<void> updateSettings(SettingsModel newSettings) async {
    try {
      await _settingsRepository.saveSettings(newSettings);
      state = newSettings;
    } catch (_) {
      state = newSettings; // Still update local state for presentation feedback
    }
  }
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, SettingsModel>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repo);
});
