import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _tokenKey = "auth_token";
  static const String _userKey  = "auth_user";
  static const String _expiryKey = "auth_expiration";

  /// Guarda token y datos de usuario
  static Future<void> saveSession(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
    final expiresAt = user['session_expires_at'];
    if (expiresAt is String) {
      await prefs.setString(_expiryKey, expiresAt);
    } else {
      await prefs.remove(_expiryKey);
    }
  }

  /// Retorna el token guardado (o null si no hay)
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Retorna los datos del usuario como Map
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_userKey);
    if (json == null) return null;
    return jsonDecode(json);
  }

  /// Borra la sesión por completo
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_expiryKey);
  }

  /// Verifica si hay sesión activa
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    final expiration = await _getExpiration();
    if (token == null || expiration == null) return false;
    return DateTime.now().isBefore(expiration);
  }

  static Future<DateTime?> _getExpiration() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_expiryKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}
