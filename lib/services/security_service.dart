import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ui_system/components/pin_pad.dart';
class SecurityService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _pinKey = 'user_pin_code';
  static const String _quickAccessPromptKey = 'quick_access_prompted_';

  static Future<bool> canUseBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticateBiometric({
    String reason = 'Confirma tu identidad para continuar.',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasPin() async {
    final stored = await _storage.read(key: _pinKey);
    return stored != null && stored.isNotEmpty;
  }

  static Future<bool> isPinValid(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    if (stored == null || stored.isEmpty) return false;
    return stored == pin;
  }

  static Future<void> clearPin() async {
    await _storage.delete(key: _pinKey);
  }

  static Future<bool> shouldShowQuickAccessPrompt(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('$_quickAccessPromptKey$userId') ?? false);
  }

  static Future<void> markQuickAccessPrompted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_quickAccessPromptKey$userId', true);
  }

  static Future<bool> setPin(BuildContext context) async {
    String? pendingPin;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final muted =
            theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? Colors.grey;
        var step = 0;
        var firstPin = '';
        var resetToken = 0;
        String? error;
        return StatefulBuilder(
          builder: (context, setModalState) {
            void clearError() {
              if (error == null) return;
              setModalState(() => error = null);
            }

            void resetWithError(String message) {
              setModalState(() {
                error = message;
                resetToken += 1;
              });
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: muted.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step == 0 ? 'Configurar PIN' : 'Confirmar PIN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step == 0
                          ? 'Crea un PIN de 4 digitos para acceder rapido.'
                          : 'Repite tu PIN para confirmar.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 16),
                    PinPad(
                      length: 4,
                      resetToken: resetToken,
                      errorText: error,
                      onChanged: (_) => clearError(),
                      onCompleted: (pin) {
                        if (step == 0) {
                          firstPin = pin;
                          setModalState(() {
                            step = 1;
                            resetToken += 1;
                            error = null;
                          });
                          return;
                        }
                        if (pin != firstPin) {
                          resetWithError('La confirmacion no coincide.');
                          return;
                        }
                        pendingPin = pin;
                        Navigator.of(sheetContext).pop(true);
                      },
                    ),
                    const SizedBox(height: 8),
                    if (step == 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            setModalState(() {
                              step = 0;
                              firstPin = '';
                              resetToken += 1;
                              error = null;
                            });
                          },
                          child: const Text('Cambiar PIN'),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != true || pendingPin == null) return false;
    await _storage.write(key: _pinKey, value: pendingPin);
    return true;
  }

  static Future<bool> verifyPin(BuildContext context) async {
    final stored = await _storage.read(key: _pinKey);
    if (stored == null || stored.isEmpty) return false;
    if (!context.mounted) return false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final muted =
            theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? Colors.grey;
        String? error;
        var resetToken = 0;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: muted.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ingresar PIN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ingresa tu PIN para continuar.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 16),
                    PinPad(
                      length: 4,
                      resetToken: resetToken,
                      errorText: error,
                      onChanged: (_) {
                        if (error == null) return;
                        setModalState(() => error = null);
                      },
                      onCompleted: (pin) {
                        if (pin != stored) {
                          setModalState(() {
                            error = 'PIN incorrecto.';
                            resetToken += 1;
                          });
                          return;
                        }
                        Navigator.of(sheetContext).pop(true);
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return result == true;
  }

  static Future<bool> requireAuthentication({
    required BuildContext context,
    required bool useBiometrics,
    required bool usePin,
    String reason = 'Confirma tu identidad para continuar.',
  }) async {
    if (!useBiometrics && !usePin) return true;
    if (useBiometrics) {
      final available = await canUseBiometrics();
      if (available) {
        final ok = await authenticateBiometric(reason: reason);
        if (ok) return true;
      }
    }
    if (usePin) {
      if (!context.mounted) return false;
      return await verifyPin(context);
    }
    return false;
  }
}
