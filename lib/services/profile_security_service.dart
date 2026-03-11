import 'api_service.dart';

class OtpRequestResult {
  final DateTime? expiresAt;
  final String? targetHint;
  final String? debugCode;

  const OtpRequestResult({
    this.expiresAt,
    this.targetHint,
    this.debugCode,
  });

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) {
    return OtpRequestResult(
      expiresAt: DateTime.tryParse((json['expires_at'] ?? '').toString()),
      targetHint: (json['target_hint'] ?? '').toString().trim().isEmpty
          ? null
          : (json['target_hint'] as String),
      debugCode: (json['debug_code'] ?? '').toString().trim().isEmpty
          ? null
          : (json['debug_code'] as String),
    );
  }
}

class ProfileSecurityService {
  const ProfileSecurityService._();

  static Future<bool> isTwoFactorEnabled({
    required String token,
  }) async {
    final data = await ApiService.getTwoFactorStatus(token: token);
    return data['enabled'] == true;
  }

  static Future<OtpRequestResult> requestTwoFactorCode({
    required String token,
    String channel = 'email',
  }) async {
    final data = await ApiService.requestTwoFactorCode(
      token: token,
      channel: channel,
    );
    return OtpRequestResult.fromJson(data);
  }

  static Future<void> verifyTwoFactorCode({
    required String token,
    required String code,
  }) async {
    await ApiService.verifyTwoFactorCode(
      token: token,
      code: code,
    );
  }

  static Future<void> setTwoFactorEnabled({
    required String token,
    required bool enabled,
  }) async {
    await ApiService.setTwoFactorEnabled(
      token: token,
      enabled: enabled,
    );
  }

  static Future<OtpRequestResult> requestContactVerification({
    required String token,
    required String kind,
    required String value,
  }) async {
    final data = await ApiService.requestContactVerification(
      token: token,
      kind: kind,
      value: value,
    );
    return OtpRequestResult.fromJson(data);
  }
}
