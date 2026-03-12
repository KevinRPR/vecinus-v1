import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

import '../models/inmueble.dart';
import '../models/user.dart';
import '../models/payment_report.dart';
import 'observability_service.dart';

class ApiAuthException implements Exception {
  final String message;

  const ApiAuthException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  static const String _defaultBaseUrl =
      'https://mail.rhodiumdev.com/condominio/movil/';
  static final String baseUrl = _normalizeBaseUrl(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: _defaultBaseUrl,
    ),
  );
  static String get baseRoot => baseUrl.replaceFirst(RegExp(r'movil/?$'), '');

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static Map<String, String> get _headers =>
      const {'Content-Type': 'application/json'};
  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _retryDelay = Duration(milliseconds: 350);
  static const int _maxAttempts = 2;
  static const String _noConnectionMessage =
      'No hay conexión, intenta de nuevo.';
  static const String _secureConnectionMessage =
      'No se pudo establecer conexión segura con el servidor.';

  static String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return _defaultBaseUrl;
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }

  static Future<http.Response> _postJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    var attempt = 0;
    while (true) {
      try {
        return await http
            .post(
              _uri(path),
              headers: _headers,
              body: jsonEncode(payload),
            )
            .timeout(_timeout);
      } on TimeoutException {
        await ObservabilityService.logEvent(
          'api_timeout',
          data: {'path': path, 'attempt': attempt + 1},
        );
        attempt += 1;
        if (attempt >= _maxAttempts) {
          throw Exception(_noConnectionMessage);
        }
        await Future<void>.delayed(_retryDelay);
      } on SocketException {
        await ObservabilityService.logEvent(
          'api_socket_error',
          data: {'path': path, 'attempt': attempt + 1},
        );
        attempt += 1;
        if (attempt >= _maxAttempts) {
          throw Exception(_noConnectionMessage);
        }
        await Future<void>.delayed(_retryDelay);
      } on HandshakeException {
        await ObservabilityService.captureException(
          const HandshakeException(_secureConnectionMessage),
          context: 'api_handshake_error',
          data: {'path': path},
        );
        throw Exception(_secureConnectionMessage);
      }
    }
  }

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
    final response = await _postJson(
      'login.php',
      {'email': email, 'password': password},
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Error desconocido');
    }
  }

  static Future<void> logout(String token) async {
    final response = await _postJson(
      'logout.php',
      {'token': token},
    );
    final data = _decodeResponse(response);
    if (response.statusCode == 200 && data['success'] == true) {
      return;
    }
    throw Exception(data['error'] ?? 'No se pudo cerrar la sesion');
  }

  static Future<List<Inmueble>> getMisInmuebles(String token) async {
    final response = await _postJson(
      'mis_inmuebles.php',
      {'token': token},
    );

    final data = _decodeResponse(response);

    if (response.statusCode == 200 && data['success'] == true) {
      final List lista = data['inmuebles'];
      return lista.map((e) => Inmueble.fromJson(e)).toList();
    }

    final message = data['error'] ?? 'Error desconocido';
    if (response.statusCode == 401) {
      throw ApiAuthException(message);
    }
    throw Exception(message);
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

  static Future<Map<String, dynamic>> getTwoFactorStatus({
    required String token,
  }) async {
    final data = await _postProfile(
      {
        'token': token,
        'accion': '2fa_status',
      },
      expectUser: false,
    );
    if (data is Map<String, dynamic>) return data;
    throw Exception('Respuesta invalida de seguridad.');
  }

  static Future<Map<String, dynamic>> requestTwoFactorCode({
    required String token,
    String channel = 'email',
  }) async {
    final data = await _postProfile(
      {
        'token': token,
        'accion': '2fa_request',
        'canal': channel,
      },
      expectUser: false,
    );
    if (data is Map<String, dynamic>) return data;
    throw Exception('Respuesta invalida de seguridad.');
  }

  static Future<Map<String, dynamic>> verifyTwoFactorCode({
    required String token,
    required String code,
  }) async {
    final data = await _postProfile(
      {
        'token': token,
        'accion': '2fa_verify',
        'codigo': code,
      },
      expectUser: false,
    );
    if (data is Map<String, dynamic>) return data;
    throw Exception('Respuesta invalida de seguridad.');
  }

  static Future<Map<String, dynamic>> setTwoFactorEnabled({
    required String token,
    required bool enabled,
  }) async {
    final data = await _postProfile(
      {
        'token': token,
        'accion': enabled ? '2fa_enable' : '2fa_disable',
      },
      expectUser: false,
    );
    if (data is Map<String, dynamic>) return data;
    throw Exception('Respuesta invalida de seguridad.');
  }

  static Future<Map<String, dynamic>> requestContactVerification({
    required String token,
    required String kind,
    required String value,
  }) async {
    final data = await _postProfile(
      {
        'token': token,
        'accion': 'contact_verification_request',
        'tipo': kind,
        'valor': value,
      },
      expectUser: false,
    );
    if (data is Map<String, dynamic>) return data;
    throw Exception('Respuesta invalida de verificacion.');
  }

  static Future<String?> uploadAvatar({
    required String token,
    required String base64Image,
  }) async {
    final response = await _postJson(
      'perfil_usuario.php',
      {
        'token': token,
        'accion': 'avatar',
        'avatar_base64': base64Image,
      },
    );

    final data = _decodeResponse(response);
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
    final response = await _postJson(
      'reportar_pago.php',
      {
        'accion': 'preparar',
        'token': token,
        'id_inmueble': inmuebleId,
      },
    );
    final data = _decodeResponse(response);
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

    final response = await _postJson(
      'reportar_pago.php',
      {
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
      },
    );
    final data = _decodeResponse(response);
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
    final response = await _postJson('mis_pagos_reportados.php', payload);
    final data = _decodeResponse(response);
    if (response.statusCode == 200 && data['success'] == true) {
      final List lista = data['reportes'] ?? [];
      return lista
          .whereType<Map<String, dynamic>>()
          .map(PaymentReport.fromJson)
          .toList();
    }
    throw Exception(
        data['error'] ?? 'No se pudo consultar los pagos reportados');
  }

  static Future<dynamic> _postProfile(
    Map<String, dynamic> payload, {
    bool expectUser = true,
  }) async {
    final response = await _postJson('perfil_usuario.php', payload);
    final data = _decodeResponse(response);

    if (response.statusCode == 200 && data['success'] == true) {
      if (expectUser) {
        return data['usuario'];
      }
      return data;
    }

    final probe = data['probe'];
    if (probe is String && probe.trim().isNotEmpty) {
      throw Exception(
        'perfil_usuario.php esta en modo prueba ($probe). Quita el probe del servidor para habilitar perfil y 2FA.',
      );
    }

    throw Exception(data['error'] ?? 'Error de perfil');
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    final body = response.body;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const FormatException('Respuesta JSON inesperada');
    } on FormatException {
      unawaited(
        ObservabilityService.captureException(
          const FormatException('Respuesta JSON invalida'),
          context: 'api_decode_error',
          data: {
            'status_code': response.statusCode,
            'body_prefix': body.trimLeft().substring(
                  0,
                  body.trimLeft().length.clamp(0, 120).toInt(),
                ),
          },
        ),
      );
      final trimmed = body.trimLeft().toLowerCase();
      if (trimmed.startsWith('<!doctype') || trimmed.startsWith('<html')) {
        if (trimmed.contains('cloudflare')) {
          throw Exception(
            'Cloudflare está bloqueando la app. Permite el endpoint en el WAF o usa un subdominio de API sin challenge.',
          );
        }
        throw Exception(
          'El servidor devolvió HTML en lugar de JSON. Revisa el endpoint o la configuración del servidor.',
        );
      }
      throw Exception('Respuesta inválida del servidor.');
    }
  }
}
