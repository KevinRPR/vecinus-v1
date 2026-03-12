import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'token_refresher.dart';

class AuthService {
  static const String _tokenKey = "auth_token";
  static const String _userKey = "auth_user";
  static const String _expiryKey = "auth_expiration";
  static const String _cacheInmueblesKey = 'cache_inmuebles';
  static const String _cacheFetchKey = 'cache_inmuebles_fetched_at';
  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  static bool _migratedLegacy = false;
  static const String _defaultSessionMinutesEnv = 'DEFAULT_SESSION_MINUTES';

  /// Guarda token y datos de usuario
  static Future<void> saveSession(String token, Map<String, dynamic> user) async {
    await _secure.write(key: _tokenKey, value: token);
    await _secure.write(key: _userKey, value: jsonEncode(user));

    final expiresAt = user['session_expires_at'];
    final resolved = _parseExpiration(expiresAt) ?? _fallbackExpiration();
    await _secure.write(
      key: _expiryKey,
      value: resolved.toIso8601String(),
    );

    await _clearLegacySession();
  }

  /// Retorna el token guardado (o null si no hay)
  static Future<String?> getToken() async {
    await _migrateLegacyIfNeeded();
    return _secure.read(key: _tokenKey);
  }

  /// Retorna los datos del usuario como Map
  static Future<Map<String, dynamic>?> getUser() async {
    await _migrateLegacyIfNeeded();
    final json = await _secure.read(key: _userKey);
    if (json == null) return null;
    return jsonDecode(json);
  }

  /// Borra la sesion por completo
  static Future<void> logout() async {
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      try {
        await ApiService.logout(token);
      } catch (_) {
        // Best-effort revocation. Local logout must continue.
      }
    }

    await _secure.delete(key: _tokenKey);
    await _secure.delete(key: _userKey);
    await _secure.delete(key: _expiryKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_expiryKey);
    await prefs.remove(_cacheInmueblesKey);
    await prefs.remove(_cacheFetchKey);
  }

  /// Verifica si hay sesion activa
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    final expiration = await _getExpiration();
    if (token == null || expiration == null) return false;
    return DateTime.now().isBefore(expiration);
  }

  static DateTime resolveSessionExpiration({
    required Map<String, dynamic> payload,
    DateTime? userExpiration,
  }) {
    final raw =
        payload['expires_at'] ?? payload['token_expires_at'] ?? payload['session_expires_at'];
    return _parseExpiration(raw) ?? userExpiration ?? _fallbackExpiration();
  }

  static Future<bool> tryRefreshSession() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    final result = await TokenRefresher.instance.tryRefresh(token);
    if (!result.refreshed) return false;
    if (result.token != null && result.token!.isNotEmpty) {
      await _secure.write(key: _tokenKey, value: result.token);
    }
    if (result.expiresAt != null) {
      await _secure.write(
        key: _expiryKey,
        value: result.expiresAt!.toIso8601String(),
      );
    }
    return true;
  }

  static Future<DateTime?> _getExpiration() async {
    await _migrateLegacyIfNeeded();
    final raw = await _secure.read(key: _expiryKey);
    if (raw == null || raw.isEmpty) {
      final token = await _secure.read(key: _tokenKey);
      if (token == null || token.isEmpty) return null;
      final fallback = _fallbackExpiration();
      await _secure.write(
        key: _expiryKey,
        value: fallback.toIso8601String(),
      );
      return fallback;
    }
    return DateTime.tryParse(raw);
  }

  static DateTime? _parseExpiration(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    if (raw is int) {
      final isMillis = raw > 2000000000;
      return DateTime.fromMillisecondsSinceEpoch(isMillis ? raw : raw * 1000);
    }
    return null;
  }

  static DateTime _fallbackExpiration() {
    return DateTime.now().add(_defaultSessionTtl());
  }

  static Duration _defaultSessionTtl() {
    const raw = String.fromEnvironment(
      _defaultSessionMinutesEnv,
      defaultValue: '10080',
    );
    final minutes = int.tryParse(raw);
    if (minutes == null || minutes <= 0) {
      return const Duration(days: 7);
    }
    return Duration(minutes: minutes);
  }

  static Future<void> _migrateLegacyIfNeeded() async {
    if (_migratedLegacy) return;
    _migratedLegacy = true;
    final existing = await _secure.read(key: _tokenKey);
    if (existing != null && existing.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_tokenKey);
    final legacyUser = prefs.getString(_userKey);
    final legacyExpiry = prefs.getString(_expiryKey);

    if (legacyToken != null && legacyToken.isNotEmpty) {
      await _secure.write(key: _tokenKey, value: legacyToken);
    }
    if (legacyUser != null && legacyUser.isNotEmpty) {
      await _secure.write(key: _userKey, value: legacyUser);
    }
    if (legacyExpiry != null && legacyExpiry.isNotEmpty) {
      await _secure.write(key: _expiryKey, value: legacyExpiry);
    }

    await _clearLegacySession();
  }

  static Future<void> _clearLegacySession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_expiryKey);
  }
}
