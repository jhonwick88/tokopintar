import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

class LicenseState {
  final bool isActivated;
  final String? token;
  final String? machineFingerprint;
  final Map<String, dynamic> features;
  final bool isLoading;
  final String? errorMessage;
  final bool hasInitialized;

  LicenseState({
    this.isActivated = false,
    this.token,
    this.machineFingerprint,
    this.features = const {},
    this.isLoading = false,
    this.errorMessage,
    this.hasInitialized = false,
  });

  LicenseState copyWith({
    bool? isActivated,
    String? token,
    String? machineFingerprint,
    Map<String, dynamic>? features,
    bool? isLoading,
    String? errorMessage,
    bool? hasInitialized,
  }) {
    return LicenseState(
      isActivated: isActivated ?? this.isActivated,
      token: token ?? this.token,
      machineFingerprint: machineFingerprint ?? this.machineFingerprint,
      features: features ?? this.features,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, 
      hasInitialized: hasInitialized ?? this.hasInitialized,
    );
  }
}

class LicenseNotifier extends StateNotifier<LicenseState> {
  LicenseNotifier() : super(LicenseState()) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    
    String? fingerprint = prefs.getString('machine_fingerprint');
    if (fingerprint == null) {
      fingerprint = const Uuid().v4();
      await prefs.setString('machine_fingerprint', fingerprint);
    }

    final token = prefs.getString('license_token');
    final featuresStr = prefs.getString('license_features');
    Map<String, dynamic> features = {};
    if (featuresStr != null) {
      try {
        features = jsonDecode(featuresStr);
      } catch (_) {}
    }

    state = state.copyWith(
      machineFingerprint: fingerprint,
      token: token,
      isActivated: token != null && token.isNotEmpty,
      features: features,
      hasInitialized: true,
    );

    // Refresh from backend to ensure features are up-to-date
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'http://localhost:8181',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 3),
      ));
      final response = await dio.get('/api/license/status');
      
      final bool isActivated = response.data['is_activated'] == true;
      if (isActivated) {
        final Map<String, dynamic> features = response.data['features'] ?? {};
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('license_token', 'activated');
        await prefs.setString('license_features', jsonEncode(features));
        
        state = state.copyWith(
          isActivated: true,
          token: 'activated',
          features: features,
        );
      } else {
        await deactivate();
      }
    } catch (_) {
      // If server is down, just use the local cached state
    }
  }

  Future<bool> activate(String licenseKey) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'http://localhost:8181',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 3),
      ));

      final response = await dio.post('/api/license/activate', data: {
        'license_key': licenseKey,
        'machine_fingerprint': state.machineFingerprint,
        'app_version': '1.0.0', 
        'hostname': 'TokoPintar-POS',
        'platform': 'windows',
      });

      

      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('license_token', 'activated');
      
      Map<String, dynamic> features = {};
      if (response.data['features'] != null) {
        features = response.data['features'];
        await prefs.setString('license_features', jsonEncode(features));
      }

      state = state.copyWith(isLoading: false);
      
      Future.delayed(const Duration(seconds: 2), () {
        state = state.copyWith(
          token: 'activated',
          isActivated: true,
          features: features,
        );
      });

      
      return true;
    } catch (e) {
      String errMsg = 'Failed to activate license.';
      if (e is DioException) {
        if (e.response != null && e.response?.data != null) {
          errMsg = e.response?.data['message'] ?? errMsg;
        } else {
          errMsg = 'Network error. Make sure server is running.';
        }
      }
      
      state = state.copyWith(
        isLoading: false,
        errorMessage: errMsg,
      );
      return false;
    }
  }

  Future<void> deactivate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('license_token');
    await prefs.remove('license_features');
    state = state.copyWith(isActivated: false, token: null, features: {});
  }
}

final licenseProvider = StateNotifierProvider<LicenseNotifier, LicenseState>((ref) {
  return LicenseNotifier();
});


