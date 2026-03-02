import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = "auth_token";
  static const String _userKey = "auth_user";
  static const String _expiryKey = "auth_expiration";
  static const String _cacheInmueblesKey = 'cache_inmuebles';
  static const String _cacheFetchKey = 'cache_inmuebles_fetched_at';
  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  static bool _migratedLegacy = false;

  /// Guarda token y datos de usuario
  static Future<void> saveSession(String token, Map<String, dynamic> user) async {
    await _secure.write(key: _tokenKey, value: token);
    await _secure.write(key: _userKey, value: jsonEncode(user));

    final expiresAt = user['session_expires_at'];
    if (expiresAt is String && expiresAt.isNotEmpty) {
      await _secure.write(key: _expiryKey, value: expiresAt);
    } else if (expiresAt is DateTime) {
      await _secure.write(
        key: _expiryKey,
        value: expiresAt.toIso8601String(),
      );
    } else {
      await _secure.delete(key: _expiryKey);
    }

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

  static Future<DateTime?> _getExpiration() async {
    await _migrateLegacyIfNeeded();
    final raw = await _secure.read(key: _expiryKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
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
