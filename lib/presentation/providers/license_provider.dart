import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class LicenseState {
  final bool isActivated;
  final String? token;
  final String? machineFingerprint;
  final String? licenseId;
  final String? customerId;
  final String? planId;
  final String? maskedKey;
  final Map<String, dynamic> features;
  final bool isLoading;
  final String? errorMessage;
  final bool hasInitialized;

  LicenseState({
    this.isActivated = false,
    this.token,
    this.machineFingerprint,
    this.licenseId,
    this.customerId,
    this.planId,
    this.maskedKey,
    this.features = const {},
    this.isLoading = false,
    this.errorMessage,
    this.hasInitialized = false,
  });

  LicenseState copyWith({
    bool? isActivated,
    String? token,
    String? machineFingerprint,
    String? licenseId,
    String? customerId,
    String? planId,
    String? maskedKey,
    Map<String, dynamic>? features,
    bool? isLoading,
    String? errorMessage,
    bool? hasInitialized,
  }) {
    return LicenseState(
      isActivated: isActivated ?? this.isActivated,
      token: token ?? this.token,
      machineFingerprint: machineFingerprint ?? this.machineFingerprint,
      licenseId: licenseId ?? this.licenseId,
      customerId: customerId ?? this.customerId,
      planId: planId ?? this.planId,
      maskedKey: maskedKey ?? this.maskedKey,
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

  static String maskKey(String key) {
    final clean = key.trim();
    if (clean.length <= 8) return clean;
    final start = clean.substring(0, 4);
    final end = clean.substring(clean.length - 4);
    return '$start-****-****-$end';
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
    final licenseId = prefs.getString('license_id');
    final customerId = prefs.getString('license_customer_id');
    final planId = prefs.getString('license_plan_id');
    final maskedKey = prefs.getString('license_masked_key');

    Map<String, dynamic> features = {};
    if (featuresStr != null) {
      try {
        features = jsonDecode(featuresStr);
      } catch (_) {}
    }

    state = state.copyWith(
      machineFingerprint: fingerprint,
      token: token,
      licenseId: licenseId,
      customerId: customerId,
      planId: planId,
      maskedKey: maskedKey,
      isActivated: token != null && token.isNotEmpty,
      features: features,
      hasInitialized: true,
    );

    // Refresh from backend to ensure features are up-to-date
    _fetchStatus();
  }

  Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('local_rest_api_url') ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:8181';
  }

  Future<void> refreshStatus() async {
    await _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      final baseUrl = await _getBaseUrl();
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 3),
      ));
      final response = await dio.get('/api/license/status');
      
      final bool isActivated = response.data['is_activated'] == true;
      if (isActivated) {
        final Map<String, dynamic> features = response.data['features'] ?? {};
        final String? licenseId = response.data['license_id']?.toString();
        final String? customerId = response.data['customer_id']?.toString();
        final String? planId = response.data['plan_id']?.toString();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('license_token', 'activated');
        await prefs.setString('license_features', jsonEncode(features));
        if (licenseId != null && licenseId.isNotEmpty) {
          await prefs.setString('license_id', licenseId);
        }
        if (customerId != null && customerId.isNotEmpty) {
          await prefs.setString('license_customer_id', customerId);
        }
        if (planId != null && planId.isNotEmpty) {
          await prefs.setString('license_plan_id', planId);
        }
        
        state = state.copyWith(
          isActivated: true,
          token: 'activated',
          licenseId: licenseId ?? state.licenseId,
          customerId: customerId ?? state.customerId,
          planId: planId ?? state.planId,
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
      final baseUrl = await _getBaseUrl();
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 3),
      ));

      final response = await dio.post('/api/license/activate', data: {
        'license_key': licenseKey,
        'machine_fingerprint': state.machineFingerprint,
        'app_version': '1.0.0', 
        'hostname': 'TokoPintar-POS',
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      });

      final masked = maskKey(licenseKey);
      final String? licenseId = response.data['license_id']?.toString();
      final String? customerId = response.data['customer_id']?.toString();
      final String? planId = response.data['plan_id']?.toString();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('license_token', 'activated');
      await prefs.setString('license_masked_key', masked);
      if (licenseId != null && licenseId.isNotEmpty) {
        await prefs.setString('license_id', licenseId);
      }
      if (customerId != null && customerId.isNotEmpty) {
        await prefs.setString('license_customer_id', customerId);
      }
      if (planId != null && planId.isNotEmpty) {
        await prefs.setString('license_plan_id', planId);
      }
      
      Map<String, dynamic> features = {};
      if (response.data['features'] != null) {
        features = response.data['features'];
        await prefs.setString('license_features', jsonEncode(features));
      }

      state = state.copyWith(
        isLoading: false,
        token: 'activated',
        isActivated: true,
        maskedKey: masked,
        licenseId: licenseId ?? state.licenseId,
        customerId: customerId ?? state.customerId,
        planId: planId ?? state.planId,
        features: features,
        errorMessage: null,
      );
      
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

  Future<bool> requestTrial() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final baseUrl = await _getBaseUrl();
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 3),
      ));

      final response = await dio.post('/api/license/trial');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('license_token', 'activated');
      
      Map<String, dynamic> features = {};
      if (response.data['features'] != null) {
        features = response.data['features'];
        await prefs.setString('license_features', jsonEncode(features));
      }

      state = state.copyWith(
        isLoading: false,
        token: 'activated',
        isActivated: true,
        features: features,
        errorMessage: null,
      );

      return true;
    } catch (e) {
      String errMsg = 'Gagal mengambil trial 14 hari.';
      if (e is DioException) {
        if (e.response != null && e.response?.data != null) {
          errMsg = e.response?.data['message'] ?? errMsg;
        } else {
          errMsg = 'Network error. Pastikan server (rest_go_toko) menyala.';
        }
      }
      state = state.copyWith(isLoading: false, errorMessage: errMsg);
      return false;
    }
  }

  Future<void> deactivate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('license_token');
    await prefs.remove('license_features');
    await prefs.remove('license_id');
    await prefs.remove('license_customer_id');
    await prefs.remove('license_plan_id');
    await prefs.remove('license_masked_key');
    state = state.copyWith(
      isActivated: false,
      token: null,
      licenseId: null,
      customerId: null,
      planId: null,
      maskedKey: null,
      features: {},
    );
  }
}

final licenseProvider = StateNotifierProvider<LicenseNotifier, LicenseState>((ref) {
  return LicenseNotifier();
});


