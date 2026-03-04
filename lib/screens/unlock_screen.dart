import 'package:flutter/material.dart';

import '../animations/transitions.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';
import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attemptUnlock());
  }

  Future<void> _attemptUnlock() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final allowed = await SecurityService.requireAuthentication(
      context: context,
      useBiometrics: widget.security.biometricForLogin,
      usePin: widget.security.pinForLogin,
      reason: 'Confirma tu identidad para continuar.',
    );

    if (!mounted) return;
    if (allowed) {
      Navigator.pushReplacement(
        context,
        fadeSlideRoute(MainShell(user: widget.user, token: widget.token)),
      );
      return;
    }

    setState(() {
      _loading = false;
      _error = 'No se pudo verificar tu identidad.';
    });
  }

  Future<void> _usePassword() async {
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
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
              const SizedBox(height: 20),
              Text(
                'Desbloquear cuenta',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Confirma tu identidad para continuar.',
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
              ElevatedButton(
                onPressed: _loading ? null : _attemptUnlock,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Desbloquear'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : _usePassword,
                child: const Text('Usar contrasena'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
