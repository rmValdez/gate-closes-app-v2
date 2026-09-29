import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gate_closes/features/auth/data/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two-tier local storage:
/// * [SharedPreferences] for non-sensitive values (flags, prefs, cached user).
/// * [FlutterSecureStorage] for secrets (auth tokens) — encrypted at rest.
class StorageService {
  StorageService(this._prefs, {FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userModelKey = 'cached_user_model';
  static const String _onboardingKey = 'onboarding_seen';

  // --- Plain key/value ---
  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  Future<void> remove(String key) => _prefs.remove(key);

  // --- Secure (access token) ---
  Future<void> saveToken(String token) =>
      _secure.write(key: _tokenKey, value: token);
  Future<String?> readToken() => _secure.read(key: _tokenKey);

  // --- Secure (refresh token) ---
  Future<void> saveRefreshToken(String token) =>
      _secure.write(key: _refreshTokenKey, value: token);
  Future<String?> readRefreshToken() => _secure.read(key: _refreshTokenKey);

  // --- Cached user model (SharedPreferences, for instant cold start) ---
  Future<void> saveUserModel(UserModel user) =>
      _prefs.setString(_userModelKey, jsonEncode(user.toJson()));

  UserModel? readUserModel() {
    final raw = _prefs.getString(_userModelKey);
    if (raw == null) return null;
    try {
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final user = UserModel.fromJson(json);
      // Older builds cached tokens here in plaintext — rewrite the entry
      // without them (toJson no longer emits tokens).
      if (json.containsKey('token') || json.containsKey('refreshToken')) {
        unawaited(saveUserModel(user));
      }
      return user;
    } on Object catch (_) {
      return null;
    }
  }

  // --- Onboarding flag ---
  // Keyed per user so a second account on the same device still gets
  // onboarding. The legacy device-wide flag (pre-per-user builds) still
  // counts as seen, so existing users aren't shown it again after upgrade.
  bool isOnboardingSeen(String userId) =>
      _prefs.getBool('$_onboardingKey:$userId') ??
      _prefs.getBool(_onboardingKey) ??
      false;
  Future<void> setOnboardingSeen(String userId) =>
      _prefs.setBool('$_onboardingKey:$userId', true);

  /// Clears the whole authenticated session (tokens + cached user).
  Future<void> clearSession() async {
    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _refreshTokenKey);
    await _prefs.remove(_userModelKey);
  }
}

/// Overridden in `main()` with the resolved instance — see [ProviderScope].
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  ),
);

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(ref.watch(sharedPreferencesProvider)),
);
