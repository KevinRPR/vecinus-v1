import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class TokenRefreshResult {
  final bool refreshed;
  final String? token;
  final DateTime? expiresAt;

  const TokenRefreshResult({
    required this.refreshed,
    this.token,
    this.expiresAt,
  });

  const TokenRefreshResult.notRefreshed() : this(refreshed: false);
}

abstract class TokenRefresher {
  static TokenRefresher instance = const HttpTokenRefresher();

  Future<TokenRefreshResult> tryRefresh(String token);
}

class HttpTokenRefresher implements TokenRefresher {
  const HttpTokenRefresher();

  static const Duration _timeout = Duration(seconds: 15);
  static http.Client _client = http.Client();

  static void setClientForTesting(http.Client client) {
    _client = client;
  }

  static void resetClientForTesting() {
    _client = http.Client();
  }

  @override
  Future<TokenRefreshResult> tryRefresh(String token) async {
    if (token.trim().isEmpty) return const TokenRefreshResult.notRefreshed();
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiService.baseUrl}refresh_token.php'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return const TokenRefreshResult.notRefreshed();
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const TokenRefreshResult.notRefreshed();
      }
      if (decoded['success'] != true) {
        return const TokenRefreshResult.notRefreshed();
      }

      final nextToken = (decoded['token'] ?? '').toString().trim();
      final expiresAt = _parseExpiration(
        decoded['session_expires_at'] ??
            decoded['expires_at'] ??
            decoded['token_expires_at'],
      );

      if (nextToken.isEmpty) {
        return const TokenRefreshResult.notRefreshed();
      }

      return TokenRefreshResult(
        refreshed: true,
        token: nextToken,
        expiresAt: expiresAt,
      );
    } on TimeoutException {
      return const TokenRefreshResult.notRefreshed();
    } on FormatException {
      return const TokenRefreshResult.notRefreshed();
    } catch (_) {
      return const TokenRefreshResult.notRefreshed();
    }
  }

  DateTime? _parseExpiration(dynamic raw) {
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    if (raw is int) {
      final isMillis = raw > 2000000000;
      return DateTime.fromMillisecondsSinceEpoch(isMillis ? raw : raw * 1000);
    }
    return null;
  }
}

class NoopTokenRefresher implements TokenRefresher {
  const NoopTokenRefresher();

  @override
  Future<TokenRefreshResult> tryRefresh(String token) async {
    return const TokenRefreshResult.notRefreshed();
  }
}
