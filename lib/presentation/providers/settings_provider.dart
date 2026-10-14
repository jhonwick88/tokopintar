import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/api_client.dart';
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
import '../../domain/repositories/supplier_repository.dart';
import '../../data/repositories/supplier_repository_impl.dart';

// --- DATA SOURCE PROVIDERS ---
final apiClientProvider = Provider<ApiClient>((ref) {
  final restApiUrl = ref.watch(settingsNotifierProvider.select((s) => s.restApiUrl));
  return ApiClient(baseUrl: restApiUrl);
});

// --- REPOSITORY PROVIDERS ---
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(apiClientProvider));
});

final itemsRepositoryProvider = Provider<ItemsRepository>((ref) {
  return ItemsRepositoryImpl(ref.watch(apiClientProvider));
});

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepositoryImpl(ref.watch(apiClientProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl();
});

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupplierRepositoryImpl(ref.watch(apiClientProvider));
});

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  return AuditRepositoryImpl(ref.watch(apiClientProvider));
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

  Future<void> setServerUrl(String newUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_rest_api_url', newUrl);
    await loadSettings();
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
