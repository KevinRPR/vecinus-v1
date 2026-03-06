import 'package:flutter/material.dart';

import '../animations/transitions.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';
import '../preferences_controller.dart';
import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import '../ui_system/components/pin_pad.dart';
import '../ui_system/feedback/app_haptics.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class UnlockScreen extends StatefulWidget {
  final User user;
  final String token;
  final SecurityPreferences security;

  const UnlockScreen({
    super.key,
    required this.user,
    required this.token,
    required this.security,
  });

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  bool _loading = false;
  String? _error;
  int _pinReset = 0;
  bool _autoBiometricAttempted = false;
  bool _pinAvailable = true;
  bool _checkingPin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoBiometric());
    _loadPinStatus();
  }

  Future<void> _loadPinStatus() async {
    if (!widget.security.pinForLogin) return;
    setState(() => _checkingPin = true);
    final hasPin = await SecurityService.hasPin();
    if (!mounted) return;
    setState(() {
      _pinAvailable = hasPin;
      _checkingPin = false;
    });
  }

  void _maybeAutoBiometric() {
    if (_autoBiometricAttempted) return;
    _autoBiometricAttempted = true;
    if (widget.security.biometricForLogin) {
      _attemptBiometric();
    }
  }

  Future<void> _attemptBiometric() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await SecurityService.authenticateBiometric(
      reason: 'Confirma tu identidad para continuar.',
    );

    if (!mounted) return;
    if (ok) {
      AppHaptics.confirm();
      await _completeUnlock();
      return;
    }

    setState(() {
      _loading = false;
      _pinReset += 1;
      _error = widget.security.pinForLogin
          ? 'No se pudo verificar la biometria. Ingresa tu PIN.'
          : 'No se pudo verificar tu identidad.';
    });
  }

  Future<void> _handlePinCompleted(String pin) async {
    if (_loading) return;
    final valid = await SecurityService.isPinValid(pin);
    if (!mounted) return;
    if (valid) {
      AppHaptics.confirm();
      await _completeUnlock();
      return;
    }
    setState(() {
      _error = _pinAvailable
          ? 'PIN incorrecto.'
          : 'PIN no configurado. Ingresa con contrasena para configurarlo.';
      _pinReset += 1;
    });
  }

  Future<void> _completeUnlock() async {
    final token = await AuthService.getToken();
    final userMap = await AuthService.getUser();
    final valid = await AuthService.isLoggedIn();

    if (!mounted) return;
    if (token == null || token.isEmpty || userMap == null || !valid) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        fadeSlideRoute(const LoginScreen()),
      );
      return;
    }

    final user = User.fromJson(userMap);
    Navigator.pushReplacement(
      context,
      fadeSlideRoute(
        MainShell(
          user: user,
          token: token,
          fromQuickAccess: true,
        ),
      ),
    );
  }

  Future<void> _usePassword() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      fadeSlideRoute(const LoginScreen()),
    );
  }

  Future<void> _resetQuickAccess() async {
    await SecurityService.clearPin();
    preferencesController.updateWith(
      (prefs) => prefs.copyWith(
        security: prefs.security.copyWith(
          biometricForLogin: false,
          biometricForSensitive: false,
          pinForLogin: false,
          pinForSensitive: false,
        ),
      ),
    );
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      fadeSlideRoute(const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppColors.textMuted;
    final height = MediaQuery.of(context).size.height;
    final keySize = height < 720 ? 56.0 : 64.0;
    final displayName = widget.user.displayName;
    final showPin = widget.security.pinForLogin;
    final showBiometric = widget.security.biometricForLogin;
    final canShowPinPad = showPin && _pinAvailable && !_checkingPin;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: AppColors.brandBlue600.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            IconsRounded.verified_user,
                            color: AppColors.brandBlue600,
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hola, $displayName',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.correo,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (_checkingPin)
                        const Center(child: CircularProgressIndicator())
                      else if (canShowPinPad) ...[
                        Text(
                          'Ingresa tu PIN',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        PinPad(
                          length: 4,
                          keySize: keySize,
                          resetToken: _pinReset,
                          showBiometric: showBiometric,
                          onBiometric: _loading ? null : _attemptBiometric,
                          onChanged: (_) {
                            if (_error == null) return;
                            setState(() => _error = null);
                          },
                          onCompleted: _handlePinCompleted,
                        ),
                      ] else if (showPin && !_pinAvailable) ...[
                        Text(
                          'PIN no configurado.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Entra con contrasena para volver a configurarlo.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ] else if (showBiometric) ...[
                        ElevatedButton.icon(
                          onPressed: _loading ? null : _attemptBiometric,
                          icon: const Icon(Icons.fingerprint),
                          label: _loading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Desbloquear con huella'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _loading ? null : _usePassword,
                        child: const Text('Usar contrasena'),
                      ),
                      TextButton(
                        onPressed: _loading ? null : _resetQuickAccess,
                        child: const Text('Restablecer acceso rapido'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
