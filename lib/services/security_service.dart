import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        final muted =
            Theme.of(sheetContext).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
                Colors.grey;
        String? error;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
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
                      'Configurar PIN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(sheetContext).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Crea un PIN de 4 digitos para acceder rapido.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'PIN',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Confirmar PIN',
                        counterText: '',
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 6),
                      Text(error!, style: TextStyle(color: Colors.red.shade400)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final pin = controller.text.trim();
                          final confirm = confirmController.text.trim();
                          if (pin.length != 4 || confirm.length != 4) {
                            setModalState(() {
                              error = 'Ingresa un PIN de 4 digitos.';
                            });
                            return;
                          }
                          if (pin != confirm) {
                            setModalState(() {
                              error = 'La confirmacion no coincide.';
                            });
                            return;
                          }
                          Navigator.of(sheetContext).pop(true);
                        },
                        child: const Text('Guardar PIN'),
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

    if (result != true) return false;
    await _storage.write(key: _pinKey, value: controller.text.trim());
    return true;
  }

  static Future<bool> verifyPin(BuildContext context) async {
    final stored = await _storage.read(key: _pinKey);
    if (stored == null || stored.isEmpty) return false;
    if (!context.mounted) return false;

    final controller = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        final muted =
            Theme.of(sheetContext).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
                Colors.grey;
        String? error;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
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
                        color: Theme.of(sheetContext).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ingresa tu PIN para continuar.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'PIN',
                        counterText: '',
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 6),
                      Text(error!, style: TextStyle(color: Colors.red.shade400)),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (controller.text.trim() != stored) {
                            setModalState(() {
                              error = 'PIN incorrecto.';
                            });
                            return;
                          }
                          Navigator.of(sheetContext).pop(true);
                        },
                        child: const Text('Confirmar'),
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
