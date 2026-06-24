import '../../domain/repositories/settings_repository.dart';
import '../datasources/firestore_client.dart';
import '../models/settings_model.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final FirestoreClient _firestoreClient;

  SettingsRepositoryImpl(this._firestoreClient);

  @override
  Future<SettingsModel> getSettings() {
    return _firestoreClient.getSettings();
  }

  @override
  Future<void> saveSettings(SettingsModel settings) {
    return _firestoreClient.saveSettings(settings);
  }
}
