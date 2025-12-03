import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/inmueble.dart';
import '../models/user.dart';

class ApiService {
  static const String baseUrl = 'https://rhodiumdev.com/condominio/movil/';

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static Map<String, String> get _headers =>
      const {'Content-Type': 'application/json'};

  // LOGIN
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      _uri('login.php'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Error desconocido');
    }
  }

  static Future<List<Inmueble>> getMisInmuebles(String token) async {
    final response = await http.post(
      _uri('mis_inmuebles.php'),
      headers: _headers,
      body: jsonEncode({'token': token}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      final List lista = data['inmuebles'];
      return lista.map((e) => Inmueble.fromJson(e)).toList();
    } else {
      throw Exception(data['error'] ?? 'Error desconocido');
    }
  }

  static Future<User> fetchProfile(String token) async {
    final data = await _postProfile({
      'token': token,
      'accion': 'consultar',
    });
    return User.fromJson(data);
  }

  static Future<User> updateProfile({
    required String token,
    required String nombre,
    required String apellido,
    required String correo,
  }) async {
    final data = await _postProfile({
      'token': token,
      'accion': 'actualizar',
      'nombre': nombre,
      'apellido': apellido,
      'correo': correo,
    });
    return User.fromJson(data);
  }

  static Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _postProfile({
      'token': token,
      'accion': 'password',
      'password_actual': currentPassword,
      'password_nueva': newPassword,
    }, expectUser: false);
  }

  static Future<String?> uploadAvatar({
    required String token,
    required String base64Image,
  }) async {
    final response = await http.post(
      _uri('perfil_usuario.php'),
      headers: _headers,
      body: jsonEncode({
        'token': token,
        'accion': 'avatar',
        'avatar_base64': base64Image,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['avatar_url'] as String?;
    }
    throw Exception(data['error'] ?? 'No se pudo subir la imagen');
  }

  static Future<dynamic> _postProfile(
    Map<String, dynamic> payload, {
    bool expectUser = true,
  }) async {
    final response = await http.post(
      _uri('perfil_usuario.php'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      if (expectUser) {
        return data['usuario'];
      }
      return data;
    }

    throw Exception(data['error'] ?? 'Error de perfil');
  }
}
