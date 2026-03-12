import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:gestion_condominios/services/token_refresher.dart';

void main() {
  const refresher = HttpTokenRefresher();

  tearDown(() {
    HttpTokenRefresher.resetClientForTesting();
  });

  test('refresh token success returns new token and expiration', () async {
    HttpTokenRefresher.setClientForTesting(
      MockClient((request) async {
        expect(request.url.path, endsWith('refresh_token.php'));
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['token'], 'old-token');
        return http.Response(
          jsonEncode({
            'success': true,
            'token': 'new-token',
            'session_expires_at': '2030-01-01 00:00:00',
          }),
          200,
        );
      }),
    );

    final result = await refresher.tryRefresh('old-token');

    expect(result.refreshed, isTrue);
    expect(result.token, 'new-token');
    expect(result.expiresAt, isNotNull);
  });

  test('refresh token with 401 does not refresh', () async {
    HttpTokenRefresher.setClientForTesting(
      MockClient((_) async => http.Response('{"error":"unauthorized"}', 401)),
    );

    final result = await refresher.tryRefresh('expired-token');

    expect(result.refreshed, isFalse);
    expect(result.token, isNull);
  });

  test('refresh token with malformed json does not refresh', () async {
    HttpTokenRefresher.setClientForTesting(
      MockClient((_) async => http.Response('<html>cloudflare</html>', 200)),
    );

    final result = await refresher.tryRefresh('token');

    expect(result.refreshed, isFalse);
  });
}

