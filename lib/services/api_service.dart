import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import '../models/inmueble.dart';
import '../models/user.dart';
import '../models/payment_report.dart';

class ApiService {
  static const String baseUrl = 'https://rhodiumdev.com/condominio/movil/';
  static String get baseRoot =>
      baseUrl.replaceFirst(RegExp(r'movil/?$'), '');

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static Map<String, String> get _headers =>
      const {'Content-Type': 'application/json'};

  static String generateClientUuid() {
    final Random rnd = Random.secure();
    String four() => rnd.nextInt(0xffff + 1).toRadixString(16).padLeft(4, '0');
    return '${four()}${four()}-${four()}-${four()}-${four()}-${four()}${four()}${four()}';
  }

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

  // PAGOS - REPORTE
  static Future<Map<String, dynamic>> preparePagoReporte({
    required String token,
    required String inmuebleId,
  }) async {
    final response = await http.post(
      _uri('reportar_pago.php'),
      headers: _headers,
      body: jsonEncode({
        'accion': 'preparar',
        'token': token,
        'id_inmueble': inmuebleId,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['error'] ?? 'No se pudo preparar el reporte de pago');
  }

  static Future<Map<String, dynamic>> enviarPagoReporte({
    required String token,
    required String inmuebleId,
    required String fechaPago,
    String? observacion,
    required List<Map<String, dynamic>> notificaciones,
    required List<Map<String, dynamic>> pagos,
    String? clientUuid,
    String? comprobanteBase64,
    String? comprobanteExt,
  }) async {
    final uuid = (clientUuid != null && clientUuid.trim().isNotEmpty)
        ? clientUuid.trim()
        : generateClientUuid();

    final response = await http.post(
      _uri('reportar_pago.php'),
      headers: _headers,
      body: jsonEncode({
        'accion': 'enviar',
        'token': token,
        'id_inmueble': inmuebleId,
        'fecha_pago': fechaPago,
        'observacion': observacion ?? '',
        'notificaciones': notificaciones,
        'pagos': pagos,
        'client_uuid': uuid,
        if (comprobanteBase64 != null) 'comprobante_base64': comprobanteBase64,
        if (comprobanteExt != null) 'comprobante_ext': comprobanteExt,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['error'] ?? 'No se pudo reportar el pago');
  }

  static Future<List<PaymentReport>> getMisPagosReportados({
    required String token,
    String? idInmueble,
  }) async {
    final payload = <String, dynamic>{
      'token': token,
      if (idInmueble != null) 'id_inmueble': idInmueble,
    };
    final response = await http.post(
      _uri('mis_pagos_reportados.php'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final List lista = data['reportes'] ?? [];
      return lista
          .whereType<Map<String, dynamic>>()
          .map(PaymentReport.fromJson)
          .toList();
    }
    throw Exception(data['error'] ?? 'No se pudo consultar los pagos reportados');
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
