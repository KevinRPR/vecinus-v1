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
  static TokenRefresher instance = const NoopTokenRefresher();

  Future<TokenRefreshResult> tryRefresh(String token);
}

class NoopTokenRefresher implements TokenRefresher {
  const NoopTokenRefresher();

  @override
  Future<TokenRefreshResult> tryRefresh(String token) async {
    return const TokenRefreshResult.notRefreshed();
  }
}
