import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/inmueble.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';
import '../animations/transitions.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/profile_security_service.dart';
import '../services/security_service.dart';
import '../preferences_controller.dart';
import '../theme_controller.dart';
import '../ui_system/feedback/app_haptics.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class UserScreen extends StatefulWidget {
  final User user;
  final String token;
  final List<Inmueble> inmuebles;
  final bool embedded;
  final ValueChanged<User>? onUserUpdated;

  const UserScreen({
    super.key,
    required this.user,
    required this.token,
    this.inmuebles = const [],
    this.embedded = false,
    this.onUserUpdated,
  });

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  static const String _noFavoriteValue = 'none';
  final _imagePicker = ImagePicker();

  late final TextEditingController _nombreController;
  late final TextEditingController _apellidoController;
  late final TextEditingController _correoController;

  final _passwordActualController = TextEditingController();
  final _passwordNuevaController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  User? _user;
  bool _loading = true;
  bool _savingProfile = false;
  bool _changingPassword = false;
  bool _uploadingAvatar = false;
  bool _processingTwoFactor = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.user.nombre);
    _apellidoController = TextEditingController(text: widget.user.apellido);
    _correoController = TextEditingController(text: widget.user.correo);
    _user = widget.user;
    _loading =
        false; // usamos datos locales almacenados, sin esperar llamada remota
    preferencesController.loadForUser(widget.user.id);
    _syncTwoFactorStatus();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _correoController.dispose();
    _passwordActualController.dispose();
    _passwordNuevaController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _syncProfile() async {
    try {
      final remoteUser = await ApiService.fetchProfile(widget.token);
      final sessionAware = remoteUser.copyWith(
        sessionExpiresAt:
            _user?.sessionExpiresAt ?? widget.user.sessionExpiresAt,
      );
      setState(() {
        _user = sessionAware;
        _nombreController.text = sessionAware.nombre;
        _apellidoController.text = sessionAware.apellido;
        _correoController.text = sessionAware.correo;
      });
      widget.onUserUpdated?.call(sessionAware);
      await AuthService.saveSession(widget.token, sessionAware.toJson());
    } catch (e) {
      _showSnack('No se pudo sincronizar el perfil: $e');
    }
  }

  Future<void> _syncTwoFactorStatus() async {
    try {
      final enabled = await ProfileSecurityService.isTwoFactorEnabled(
        token: widget.token,
      );
      await _setTwoFactorPreference(enabled);
    } catch (_) {
      // No bloqueamos la pantalla por errores de sincronizacion de 2FA.
    }
  }

  Future<void> _setTwoFactorPreference(bool enabled) async {
    await preferencesController.updateWith(
      (current) => current.copyWith(
        security: current.security.copyWith(twoFactorEnabled: enabled),
      ),
    );
  }

  Future<void> _toggleTwoFactor({
    required bool enabled,
    required BuildContext sheetContext,
  }) async {
    if (_processingTwoFactor) return;
    setState(() => _processingTwoFactor = true);

    final securityPrefs = preferencesController.preferences.value.security;
    try {
      final allowed = await SecurityService.requireAuthentication(
        context: context,
        useBiometrics: securityPrefs.biometricForSensitive,
        usePin: securityPrefs.pinForSensitive,
        reason: enabled
            ? 'Confirma tu identidad para activar 2FA.'
            : 'Confirma tu identidad para desactivar 2FA.',
      );
      if (!allowed) {
        _showSnack('No se pudo verificar tu identidad.');
        return;
      }

      if (!enabled) {
        try {
          await ProfileSecurityService.setTwoFactorEnabled(
            token: widget.token,
            enabled: false,
          );
          await _setTwoFactorPreference(false);
          _showSnack('2FA desactivado.');
        } catch (e) {
          _showSnack('No se pudo desactivar 2FA: $e');
        }
        return;
      }

      try {
        final request = await ProfileSecurityService.requestTwoFactorCode(
          token: widget.token,
          channel: 'email',
        );

        if (!sheetContext.mounted) return;
        final code = await _promptOtpCode(
          sheetContext: sheetContext,
          targetHint: request.targetHint,
          debugCode: request.debugCode,
          expiresAt: request.expiresAt,
        );
        if (code == null || code.isEmpty) {
          _showSnack('Activacion de 2FA cancelada.');
          return;
        }

        await ProfileSecurityService.verifyTwoFactorCode(
          token: widget.token,
          code: code,
        );
        await _setTwoFactorPreference(true);
        _showSnack('2FA activado correctamente.');
      } catch (e) {
        _showSnack('No se pudo activar 2FA: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _processingTwoFactor = false);
      }
    }
  }

  Future<String?> _promptOtpCode({
    required BuildContext sheetContext,
    String? targetHint,
    String? debugCode,
    DateTime? expiresAt,
  }) async {
    String otpCode = '';
    String? currentTargetHint = targetHint;
    String? currentDebugCode = debugCode;
    DateTime? currentExpiresAt = expiresAt;
    var resendAvailableAt = DateTime.now().add(const Duration(minutes: 1));
    bool sendingResend = false;
    Timer? ticker;

    int secondsLeft() {
      final diff = resendAvailableAt.difference(DateTime.now()).inSeconds;
      return diff > 0 ? diff : 0;
    }

    final result = await showModalBottomSheet<String>(
      context: sheetContext,
      isScrollControlled: true,
      backgroundColor: Theme.of(sheetContext).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final muted = Theme.of(context)
                .textTheme
                .bodySmall
                ?.color
                ?.withValues(alpha: 0.7) ??
            Colors.grey;
        return StatefulBuilder(
          builder: (context, setModalState) {
            ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
              if (!context.mounted) return;
              setModalState(() {});
            });

            final canResend = secondsLeft() == 0 && !sendingResend;
            final resendLabel = sendingResend
                ? 'Reenviando...'
                : canResend
                    ? 'Reenviar codigo'
                    : 'Reenviar en ${secondsLeft()}s';

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sheetHandle(muted),
                    const SizedBox(height: 12),
                    const Text(
                      'Verifica tu codigo',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentTargetHint == null
                          ? 'Ingresa el codigo temporal para activar 2FA.'
                          : 'Ingresa el codigo enviado a $currentTargetHint.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    if (currentExpiresAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Valido hasta: ${currentExpiresAt!.toLocal().toString().split('.').first}',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                    if (currentDebugCode != null &&
                        currentDebugCode!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Codigo de pruebas: $currentDebugCode',
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      onChanged: (value) => otpCode = value,
                      decoration: const InputDecoration(
                        labelText: 'Codigo OTP',
                        hintText: 'Ejemplo: 123456',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pop(otpCode.trim()),
                        child: const Text('Validar codigo'),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: canResend
                            ? () async {
                                setModalState(() => sendingResend = true);
                                try {
                                  final request = await ProfileSecurityService
                                      .requestTwoFactorCode(
                                    token: widget.token,
                                    channel: 'email',
                                  );
                                  currentTargetHint =
                                      request.targetHint ?? currentTargetHint;
                                  currentDebugCode = request.debugCode;
                                  currentExpiresAt = request.expiresAt;
                                  resendAvailableAt = DateTime.now()
                                      .add(const Duration(minutes: 1));
                                  _showSnack('Codigo reenviado.');
                                } catch (e) {
                                  _showSnack(
                                      'No se pudo reenviar el codigo: $e');
                                } finally {
                                  if (context.mounted) {
                                    setModalState(() => sendingResend = false);
                                  }
                                }
                              }
                            : null,
                        child: Text(resendLabel),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
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
    ticker?.cancel();
    return result;
  }

  Future<bool> _saveProfile() async {
    if (_savingProfile) return false;
    final nombre = _nombreController.text.trim();
    final apellido = _apellidoController.text.trim();
    final correo = _correoController.text.trim();

    if (nombre.isEmpty || apellido.isEmpty) {
      _showSnack('Completa tu nombre y apellido.');
      return false;
    }
    if (!_isValidEmail(correo)) {
      _showSnack('El correo no parece valido.');
      return false;
    }

    setState(() => _savingProfile = true);
    try {
      final updated = await ApiService.updateProfile(
        token: widget.token,
        nombre: nombre,
        apellido: apellido,
        correo: correo,
      );

      final sessionAware = updated.copyWith(
        sessionExpiresAt:
            _user?.sessionExpiresAt ?? widget.user.sessionExpiresAt,
      );

      await AuthService.saveSession(widget.token, sessionAware.toJson());

      setState(() => _user = sessionAware);
      widget.onUserUpdated?.call(sessionAware);
      _showSnack('Datos actualizados.');
      return true;
    } catch (e) {
      _showSnack('Error al actualizar: $e');
      return false;
    } finally {
      setState(() => _savingProfile = false);
    }
  }

  Future<bool> _changePassword() async {
    if (_changingPassword) return false;
    final actual = _passwordActualController.text;
    final nueva = _passwordNuevaController.text;
    final confirm = _passwordConfirmController.text;

    if (actual.isEmpty || nueva.isEmpty || confirm.isEmpty) {
      _showSnack('Completa todos los campos de contraseña.');
      return false;
    }
    if (nueva.length < 6) {
      _showSnack('La contraseña nueva debe tener al menos 6 caracteres.');
      return false;
    }
    if (nueva != confirm) {
      _showSnack('La confirmacion no coincide.');
      return false;
    }

    final securityPrefs = preferencesController.preferences.value.security;
    final allowed = await SecurityService.requireAuthentication(
      context: context,
      useBiometrics: securityPrefs.biometricForSensitive,
      usePin: securityPrefs.pinForSensitive,
      reason: 'Confirma tu identidad para cambiar la contraseña.',
    );
    if (!allowed) {
      _showSnack('No se pudo verificar tu identidad.');
      return false;
    }

    setState(() => _changingPassword = true);
    try {
      await ApiService.changePassword(
        token: widget.token,
        currentPassword: actual,
        newPassword: nueva,
      );
      _passwordActualController.clear();
      _passwordNuevaController.clear();
      _passwordConfirmController.clear();
      _showSnack('Contrasena actualizada correctamente.');
      return true;
    } catch (e) {
      _showSnack('No se pudo actualizar la contraseña: $e');
      return false;
    } finally {
      setState(() => _changingPassword = false);
    }
  }

  Future<void> _pickAvatar() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1024,
    );

    if (file == null) return;

    setState(() => _uploadingAvatar = true);

    try {
      final bytes = await file.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final avatarUrl = await ApiService.uploadAvatar(
        token: widget.token,
        base64Image: base64Image,
      );

      if (avatarUrl != null) {
        final updatedUser = (_user ?? widget.user).copyWith(
          avatarUrl: avatarUrl,
        );
        final sessionAware = updatedUser.copyWith(
          sessionExpiresAt:
              _user?.sessionExpiresAt ?? widget.user.sessionExpiresAt,
        );
        await AuthService.saveSession(widget.token, sessionAware.toJson());
        setState(() => _user = sessionAware);
        widget.onUserUpdated?.call(sessionAware);
      }

      _showSnack('Foto actualizada.');
    } catch (e) {
      _showSnack('No se pudo actualizar la foto: $e');
    } finally {
      setState(() => _uploadingAvatar = false);
    }
  }

  bool _isValidEmail(String value) {
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(value);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;

    final scaffold = Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Mi perfil'),
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(IconsRounded.arrow_back),
                tooltip: 'Volver',
                onPressed: () {
                  final user = _user ?? widget.user;
                  widget.onUserUpdated?.call(user);
                  Navigator.pop(context, user);
                },
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _syncProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  FadeSlideTransition(
                    beginOffset: const Offset(0, 0.02),
                    child: _buildProfileCard(context),
                  ),
                  const SizedBox(height: 18),
                  _buildSettingsSection(context),
                  const SizedBox(height: 18),
                  _buildSupportCard(context),
                  const SizedBox(height: 12),
                  _buildVersionFooter(context),
                ],
              ),
            ),
    );

    if (widget.embedded) {
      return scaffold;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final user = _user ?? widget.user;
        widget.onUserUpdated?.call(user);
        Navigator.pop(context, user);
      },
      child: scaffold,
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final user = _user ?? widget.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = _cardColor(isDark);
    final borderColor = _borderColor(isDark);
    final muted = _mutedColor(isDark);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openEditProfileSheet,
          child: Column(
            children: [
              Container(height: 4, color: AppColors.brandBlue600),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                child: Column(
                  children: [
                    _buildAvatar(user, isDark),
                    const SizedBox(height: 12),
                    Text(
                      user.displayName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _profileSubtitle(user),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.correo,
                      style: TextStyle(
                        fontSize: 11,
                        color: muted.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(User user, bool isDark) {
    final avatarUrl = user.avatarUrl;
    final fallback = Container(
      color: AppColors.brandBlue600.withValues(alpha: 0.12),
      child: const Icon(
        IconsRounded.person,
        color: AppColors.brandBlue600,
        size: 36,
      ),
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: AppColors.brandBlue600.withValues(alpha: 0.2), width: 4),
          ),
          child: ClipOval(
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => fallback,
                  )
                : fallback,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Semantics(
            button: true,
            enabled: !_uploadingAvatar,
            label: 'Cambiar foto de perfil',
            child: Tooltip(
              message: 'Cambiar foto de perfil',
              child: Material(
                color: Colors.transparent,
                child: InkResponse(
                  onTap: _uploadingAvatar ? null : _pickAvatar,
                  radius: 24,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.brandBlue600,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkSurface
                                : AppColors.surface,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _uploadingAvatar
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                IconsRounded.photo_camera,
                                color: Colors.white,
                                size: 16,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _profileSubtitle(User user) {
    if (user.id.trim().isEmpty) return 'Cuenta Vecinus';
    return 'Usuario #${user.id}';
  }

  Widget _buildSettingsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = _cardColor(isDark);
    final borderColor = _borderColor(isDark);
    final muted = _mutedColor(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONFIGURACION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: muted,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              _settingsTile(
                icon: IconsRounded.settings,
                iconColor: AppColors.brandBlue600,
                iconBackground: AppColors.brandBlue600.withValues(alpha: 0.12),
                title: 'Preferencias',
                subtitle: 'Notificaciones, idioma...',
                showDivider: true,
                dividerColor: borderColor,
                onTap: _openPreferencesSheet,
              ),
              _settingsTile(
                icon: IconsRounded.security,
                iconColor: AppColors.brandTeal600,
                iconBackground: AppColors.brandTeal600.withValues(alpha: 0.12),
                title: 'Seguridad',
                subtitle: 'Cambiar contraseña, 2FA',
                showDivider: true,
                dividerColor: borderColor,
                onTap: _openSecuritySheet,
              ),
              _settingsTile(
                icon: IconsRounded.logout,
                iconColor: AppColors.error,
                iconBackground: AppColors.error.withValues(alpha: 0.12),
                title: 'Cerrar sesión',
                showChevron: false,
                isDestructive: true,
                dividerColor: borderColor,
                onTap: _handleLogout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    String? subtitle,
    bool showDivider = false,
    bool showChevron = true,
    bool isDestructive = false,
    Color? dividerColor,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = _mutedColor(isDark);
    final textColor =
        isDestructive ? iconColor : Theme.of(context).colorScheme.onSurface;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? iconBackground.withValues(alpha: 0.25)
                          : iconBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showChevron)
                    Icon(IconsRounded.chevron_right, color: muted),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: dividerColor ?? _borderColor(isDark),
          ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      fadeSlideRoute(const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildSupportCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = _mutedColor(isDark);
    final background =
        AppColors.brandBlue600.withValues(alpha: isDark ? 0.12 : 0.1);
    final borderColor =
        AppColors.brandBlue600.withValues(alpha: isDark ? 0.3 : 0.2);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brandBlue600,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(IconsRounded.support_agent, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Necesitas ayuda?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nuestro equipo de soporte esta disponible para asistirte con cualquier duda sobre tu comunidad.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _openSupportSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandBlue600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Contactar soporte',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionFooter(BuildContext context) {
    final muted = _mutedColor(Theme.of(context).brightness == Brightness.dark)
        .withValues(alpha: 0.8);
    return Center(
      child: Text(
        'Vecinus App v2.4.0',
        style: TextStyle(fontSize: 11, color: muted),
      ),
    );
  }

  void _openEditProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final muted = _mutedColor(isDark);

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(muted),
                const SizedBox(height: 12),
                Text(
                  'Editar perfil',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(sheetContext).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInputLabel('Nombre'),
                _buildTextField(_nombreController, TextInputType.name),
                const SizedBox(height: 12),
                _buildInputLabel('Apellido'),
                _buildTextField(_apellidoController, TextInputType.name),
                const SizedBox(height: 12),
                _buildInputLabel('Correo'),
                _buildTextField(_correoController, TextInputType.emailAddress),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savingProfile
                        ? null
                        : () async {
                            final saved = await _saveProfile();
                            if (!mounted) return;
                            if (!sheetContext.mounted) return;
                            if (saved) Navigator.of(sheetContext).pop();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandBlue600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _savingProfile
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Guardar cambios',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPreferencesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final muted = _mutedColor(isDark);
        final cardColor = _cardColor(isDark);
        final borderColor = _borderColor(isDark);
        final hasMultipleInmuebles = widget.inmuebles.length > 1;

        return ValueListenableBuilder<UserPreferences>(
          valueListenable: preferencesController.preferences,
          builder: (context, prefs, _) {
            return Material(
              color: Theme.of(sheetContext).cardColor,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sheetHandle(muted),
                      const SizedBox(height: 12),
                      Text(
                        'Preferencias',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(sheetContext).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sheetSectionTitle('Accesibilidad', muted),
                      const SizedBox(height: 8),
                      _sheetCard(
                        cardColor: cardColor,
                        borderColor: borderColor,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tamano de letra',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(sheetContext)
                                    .colorScheme
                                    .onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Escala actual: ${(prefs.textScale * 100).round()}%',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Slider(
                                value: prefs.textScale,
                                min: 0.85,
                                max: 1.25,
                                divisions: 8,
                                label: '${(prefs.textScale * 100).round()}%',
                                activeColor: AppColors.brandBlue600,
                                onChanged: (value) {
                                  preferencesController.updateWith(
                                    (current) =>
                                        current.copyWith(textScale: value),
                                  );
                                },
                              ),
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Alto contraste',
                              subtitle: 'Mejora la legibilidad.',
                              value: prefs.highContrast,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (value) {
                                preferencesController.updateWith(
                                  (current) =>
                                      current.copyWith(highContrast: value),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Reducir animaciones',
                              subtitle: 'Minimiza los movimientos en pantalla.',
                              value: prefs.reduceMotion,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (value) {
                                preferencesController.updateWith(
                                  (current) =>
                                      current.copyWith(reduceMotion: value),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sheetSectionTitle('Tema', muted),
                      const SizedBox(height: 8),
                      _sheetCard(
                        cardColor: cardColor,
                        borderColor: borderColor,
                        child: ValueListenableBuilder<ThemeMode>(
                          valueListenable: themeController.themeMode,
                          builder: (context, mode, _) {
                            return RadioGroup<ThemeMode>(
                              groupValue: mode,
                              onChanged: (value) {
                                if (value == null) return;
                                themeController.setThemeMode(value);
                              },
                              child: Column(
                                children: [
                                  _buildThemeTile(
                                    title: 'Sistema',
                                    subtitle: 'Se ajusta al dispositivo.',
                                    value: ThemeMode.system,
                                  ),
                                  const Divider(height: 1),
                                  _buildThemeTile(
                                    title: 'Claro',
                                    subtitle: 'Interfaz clara siempre.',
                                    value: ThemeMode.light,
                                  ),
                                  const Divider(height: 1),
                                  _buildThemeTile(
                                    title: 'Oscuro',
                                    subtitle: 'Interfaz oscura siempre.',
                                    value: ThemeMode.dark,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _sheetSectionTitle('Notificaciones', muted),
                      const SizedBox(height: 8),
                      _sheetCard(
                        cardColor: cardColor,
                        borderColor: borderColor,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionMiniTitle('Tipos', muted),
                            _buildSwitchTile(
                              title: 'Avisos',
                              subtitle: 'Comunicados de administración.',
                              value: prefs.notifications.avisos,
                              onChanged: (value) {
                                preferencesController.updateWith(
                                  (current) => current.copyWith(
                                    notifications: current.notifications
                                        .copyWith(avisos: value),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Alertas',
                              subtitle: 'Advertencias y recordatorios.',
                              value: prefs.notifications.alertas,
                              onChanged: (value) {
                                preferencesController.updateWith(
                                  (current) => current.copyWith(
                                    notifications: current.notifications
                                        .copyWith(alertas: value),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Eventos',
                              subtitle: 'Actividades y reuniones.',
                              value: prefs.notifications.eventos,
                              onChanged: (value) {
                                preferencesController.updateWith(
                                  (current) => current.copyWith(
                                    notifications: current.notifications
                                        .copyWith(eventos: value),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Pagos',
                              subtitle: 'Vencimientos y confirmaciones.',
                              value: prefs.notifications.pagos,
                              onChanged: (value) {
                                preferencesController.updateWith(
                                  (current) => current.copyWith(
                                    notifications: current.notifications
                                        .copyWith(pagos: value),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            _sectionMiniTitle('Canales', muted),
                            _buildSwitchTile(
                              title: 'Push',
                              subtitle: 'Alertas en el telefono.',
                              value: prefs.notifications.push,
                              onChanged: (value) {
                                preferencesController.updateWith(
                                  (current) => current.copyWith(
                                    notifications: current.notifications
                                        .copyWith(push: value),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Email',
                              subtitle: 'Resumenes por correo.',
                              value: prefs.notifications.email,
                              onChanged: (value) {
                                preferencesController.updateWith(
                                  (current) => current.copyWith(
                                    notifications: current.notifications
                                        .copyWith(email: value),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'WhatsApp',
                              subtitle: 'Mensajes rápidos al celular.',
                              value: prefs.notifications.whatsapp,
                              onChanged: (value) {
                                preferencesController.updateWith(
                                  (current) => current.copyWith(
                                    notifications: current.notifications
                                        .copyWith(whatsapp: value),
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              title: const Text('Horario silencio'),
                              subtitle: Text(
                                _quietHoursSummary(prefs.quietHours),
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                              trailing: Text(
                                _quietHoursStatus(prefs.quietHours),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      prefs.quietHours.isActive(DateTime.now())
                                          ? AppColors.brandBlue600
                                          : muted,
                                ),
                              ),
                              onTap: () =>
                                  _openQuietHoursSheet(prefs.quietHours),
                            ),
                          ],
                        ),
                      ),
                      if (hasMultipleInmuebles) ...[
                        const SizedBox(height: 16),
                        _sheetSectionTitle('Inmuebles', muted),
                        const SizedBox(height: 8),
                        _sheetCard(
                          cardColor: cardColor,
                          borderColor: borderColor,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _resolveFavoriteValue(
                                  prefs.inmueble.favoriteInmuebleId,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Inmueble favorito',
                                ),
                                items: _favoriteDropdownItems(),
                                onChanged: (value) {
                                  final favorite =
                                      value == _noFavoriteValue ? null : value;
                                  preferencesController.updateWith(
                                    (current) => current.copyWith(
                                      inmueble: current.inmueble.copyWith(
                                        favoriteInmuebleId: favorite,
                                        clearFavorite: favorite == null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<DashboardCardOrder>(
                                initialValue: prefs.inmueble.cardOrder,
                                decoration: const InputDecoration(
                                  labelText: 'Orden de tarjetas',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: DashboardCardOrder.balanceFirst,
                                    child: Text('Saldo primero'),
                                  ),
                                  DropdownMenuItem(
                                    value:
                                        DashboardCardOrder.announcementsFirst,
                                    child: Text('Avisos primero'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  preferencesController.updateWith(
                                    (current) => current.copyWith(
                                      inmueble: current.inmueble.copyWith(
                                        cardOrder: value,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 4),
                              _buildSwitchTile(
                                title: 'Resumen compacto',
                                subtitle:
                                    'Muestra menos detalle en el dashboard.',
                                value: prefs.inmueble.compactSummary,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (value) {
                                  preferencesController.updateWith(
                                    (current) => current.copyWith(
                                      inmueble: current.inmueble.copyWith(
                                        compactSummary: value,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cerrar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openSecuritySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final muted = _mutedColor(isDark);
        final cardColor = _cardColor(isDark);
        final borderColor = _borderColor(isDark);

        return ValueListenableBuilder<UserPreferences>(
          valueListenable: preferencesController.preferences,
          builder: (context, prefs, _) {
            final security = prefs.security;
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sheetHandle(muted),
                    const SizedBox(height: 12),
                    Text(
                      'Seguridad',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(sheetContext).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sheetSectionTitle('Cuenta', muted),
                    const SizedBox(height: 8),
                    _sheetCard(
                      cardColor: cardColor,
                      borderColor: borderColor,
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            title: const Text('Cambiar correo'),
                            subtitle: Text(
                              'Requiere verificacion.',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                            trailing:
                                Icon(IconsRounded.chevron_right, color: muted),
                            onTap: () => _openContactChangeSheet(
                              title: 'Cambiar correo',
                              hint: 'nuevo@correo.com',
                              fieldLabel: 'Correo',
                              kind: ContactKind.email,
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            title: const Text('Cambiar telefono'),
                            subtitle: Text(
                              'Enviaremos un codigo.',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                            trailing:
                                Icon(IconsRounded.chevron_right, color: muted),
                            onTap: () => _openContactChangeSheet(
                              title: 'Cambiar telefono',
                              hint: '+58 000 000 0000',
                              fieldLabel: 'Telefono',
                              kind: ContactKind.phone,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sheetSectionTitle('Acceso rápido', muted),
                    const SizedBox(height: 8),
                    _sheetCard(
                      cardColor: cardColor,
                      borderColor: borderColor,
                      child: Column(
                        children: [
                          _buildSwitchTile(
                            title: 'Biometria para entrar',
                            subtitle: 'Huella o Face ID al iniciar sesión.',
                            value: security.biometricForLogin,
                            onChanged: (value) async {
                              if (value) {
                                final available =
                                    await SecurityService.canUseBiometrics();
                                if (!available) {
                                  _showSnack(
                                    'Biometria no disponible en este dispositivo.',
                                  );
                                  return;
                                }
                                final ok =
                                    await SecurityService.authenticateBiometric(
                                  reason: 'Confirma biometría para activar.',
                                );
                                if (!ok) {
                                  _showSnack(
                                    'No se pudo verificar tu biometría.',
                                  );
                                  return;
                                }
                                AppHaptics.impact();
                              }
                              preferencesController.updateWith(
                                (current) => current.copyWith(
                                  security: current.security.copyWith(
                                    biometricForLogin: value,
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          _buildSwitchTile(
                            title: 'Biometria para acciones sensibles',
                            subtitle: 'Pagos y cambios de contraseña.',
                            value: security.biometricForSensitive,
                            onChanged: (value) async {
                              if (value) {
                                final available =
                                    await SecurityService.canUseBiometrics();
                                if (!available) {
                                  _showSnack(
                                    'Biometria no disponible en este dispositivo.',
                                  );
                                  return;
                                }
                                final ok =
                                    await SecurityService.authenticateBiometric(
                                  reason: 'Confirma biometría para activar.',
                                );
                                if (!ok) {
                                  _showSnack(
                                    'No se pudo verificar tu biometría.',
                                  );
                                  return;
                                }
                                AppHaptics.impact();
                              }
                              preferencesController.updateWith(
                                (current) => current.copyWith(
                                  security: current.security.copyWith(
                                    biometricForSensitive: value,
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          _buildSwitchTile(
                            title: 'PIN para entrar',
                            subtitle: 'Solicitar PIN al iniciar sesión.',
                            value: security.pinForLogin,
                            onChanged: (value) async {
                              if (value) {
                                final hasPin = await SecurityService.hasPin();
                                if (!sheetContext.mounted) return;
                                final created = hasPin
                                    ? true
                                    : await SecurityService.setPin(
                                        sheetContext,
                                      );
                                if (!created) return;
                              } else if (!security.pinForSensitive) {
                                await SecurityService.clearPin();
                              }
                              preferencesController.updateWith(
                                (current) => current.copyWith(
                                  security: current.security.copyWith(
                                    pinForLogin: value,
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          _buildSwitchTile(
                            title: 'PIN para acciones sensibles',
                            subtitle: 'Pagos y cambios de contraseña.',
                            value: security.pinForSensitive,
                            onChanged: (value) async {
                              if (value) {
                                final hasPin = await SecurityService.hasPin();
                                if (!sheetContext.mounted) return;
                                final created = hasPin
                                    ? true
                                    : await SecurityService.setPin(
                                        sheetContext,
                                      );
                                if (!created) return;
                              } else if (!security.pinForLogin) {
                                await SecurityService.clearPin();
                              }
                              preferencesController.updateWith(
                                (current) => current.copyWith(
                                  security: current.security.copyWith(
                                    pinForSensitive: value,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sheetSectionTitle('Contrasena', muted),
                    const SizedBox(height: 8),
                    _sheetCard(
                      cardColor: cardColor,
                      borderColor: borderColor,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInputLabel('Contrasena actual'),
                          _buildTextField(
                            _passwordActualController,
                            TextInputType.visiblePassword,
                            obscure: true,
                          ),
                          const SizedBox(height: 12),
                          _buildInputLabel('Nueva contraseña'),
                          _buildTextField(
                            _passwordNuevaController,
                            TextInputType.visiblePassword,
                            obscure: true,
                          ),
                          const SizedBox(height: 12),
                          _buildInputLabel('Confirmar contraseña'),
                          _buildTextField(
                            _passwordConfirmController,
                            TextInputType.visiblePassword,
                            obscure: true,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _changingPassword
                                  ? null
                                  : () async {
                                      final saved = await _changePassword();
                                      if (!mounted) return;
                                      if (!sheetContext.mounted) return;
                                      if (saved) {
                                        Navigator.of(sheetContext).pop();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandBlue600,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _changingPassword
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Actualizar contraseña',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sheetSectionTitle('Doble factor', muted),
                    const SizedBox(height: 8),
                    _sheetCard(
                      cardColor: cardColor,
                      borderColor: borderColor,
                      child: _buildSwitchTile(
                        title: '2FA (OTP)',
                        subtitle: _processingTwoFactor
                            ? 'Procesando...'
                            : security.twoFactorEnabled
                                ? 'Proteccion activa para acciones sensibles.'
                                : 'Activa un codigo temporal para validar cambios.',
                        value: security.twoFactorEnabled,
                        onChanged: _processingTwoFactor
                            ? null
                            : (value) async {
                                await _toggleTwoFactor(
                                  enabled: value,
                                  sheetContext: sheetContext,
                                );
                              },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Cerrar'),
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
  }

  void _openSupportSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final muted = _mutedColor(isDark);

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(muted),
                const SizedBox(height: 12),
                Text(
                  'Soporte',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(sheetContext).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Contacta a la administración de tu condominio para recibir ayuda.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: muted,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openQuietHoursSheet(QuietHours current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final muted = _mutedColor(isDark);
        var enabled = current.enabled;
        var startMinutes = current.startMinutes;
        var endMinutes = current.endMinutes;
        final days = [...current.days];

        Future<void> pickStart() async {
          final time = await showTimePicker(
            context: sheetContext,
            initialTime: _minutesToTimeOfDay(startMinutes),
          );
          if (time != null) {
            startMinutes = _timeOfDayToMinutes(time);
          }
        }

        Future<void> pickEnd() async {
          final time = await showTimePicker(
            context: sheetContext,
            initialTime: _minutesToTimeOfDay(endMinutes),
          );
          if (time != null) {
            endMinutes = _timeOfDayToMinutes(time);
          }
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sheetHandle(muted),
                    const SizedBox(height: 12),
                    Text(
                      'Horario silencio',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(sheetContext).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Activar horario silencio'),
                      subtitle: Text(
                        'Silencia notificaciones en el rango definido.',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      value: enabled,
                      activeThumbColor: AppColors.brandBlue600,
                      onChanged: (value) {
                        setModalState(() => enabled = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Desde'),
                      subtitle: Text(
                        _formatMinutes(startMinutes),
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      trailing: const Icon(IconsRounded.access_time),
                      onTap: () async {
                        await pickStart();
                        setModalState(() {});
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hasta'),
                      subtitle: Text(
                        _formatMinutes(endMinutes),
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      trailing: const Icon(IconsRounded.access_time),
                      onTap: () async {
                        await pickEnd();
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dias activos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _dayChips(days, setModalState),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final updated = current.copyWith(
                            enabled: enabled,
                            startMinutes: startMinutes,
                            endMinutes: endMinutes,
                            days: days,
                          );
                          preferencesController.updateWith(
                            (prefs) => prefs.copyWith(quietHours: updated),
                          );
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Guardar horario'),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Cerrar'),
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
  }

  List<Widget> _dayChips(List<int> selected, StateSetter setModalState) {
    const labels = {
      1: 'Lun',
      2: 'Mar',
      3: 'Mie',
      4: 'Jue',
      5: 'Vie',
      6: 'Sab',
      7: 'Dom',
    };
    return labels.entries.map((entry) {
      final isSelected = selected.contains(entry.key);
      return ChoiceChip(
        label: Text(entry.value),
        selected: isSelected,
        selectedColor: AppColors.brandBlue600.withValues(alpha: 0.2),
        onSelected: (value) {
          setModalState(() {
            if (value) {
              selected.add(entry.key);
            } else {
              selected.remove(entry.key);
            }
          });
        },
      );
    }).toList();
  }

  List<DropdownMenuItem<String>> _favoriteDropdownItems() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: _noFavoriteValue,
        child: Text('Sin favorito'),
      ),
    ];
    for (final inmueble in widget.inmuebles) {
      items.add(
        DropdownMenuItem(
          value: inmueble.idInmueble,
          child: Text(_inmuebleLabel(inmueble)),
        ),
      );
    }
    return items;
  }

  String _resolveFavoriteValue(String? favoriteId) {
    if (favoriteId == null) return _noFavoriteValue;
    final exists = widget.inmuebles.any(
      (inmueble) => inmueble.idInmueble == favoriteId,
    );
    return exists ? favoriteId : _noFavoriteValue;
  }

  void _openContactChangeSheet({
    required String title,
    required String hint,
    required String fieldLabel,
    required ContactKind kind,
  }) {
    String contactValue = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        final muted = Theme.of(sheetContext)
                .textTheme
                .bodySmall
                ?.color
                ?.withValues(alpha: 0.7) ??
            Colors.grey;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetHandle(muted),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(sheetContext).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enviaremos un codigo de verificacion.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  keyboardType: kind == ContactKind.email
                      ? TextInputType.emailAddress
                      : TextInputType.phone,
                  onChanged: (value) => contactValue = value,
                  decoration: InputDecoration(
                    labelText: fieldLabel,
                    hintText: hint,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final value = contactValue.trim();
                      if (value.isEmpty) {
                        _showSnack('Completa el campo antes de continuar.');
                        return;
                      }
                      await _requestContactVerification(kind, value);
                      if (!sheetContext.mounted) return;
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Enviar codigo'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _requestContactVerification(
    ContactKind kind,
    String value,
  ) async {
    final requestKind = kind == ContactKind.email ? 'email' : 'phone';
    try {
      final result = await ProfileSecurityService.requestContactVerification(
        token: widget.token,
        kind: requestKind,
        value: value,
      );
      final label = kind == ContactKind.email ? 'correo' : 'telefono';
      final preview = result.debugCode;
      if (preview != null && preview.isNotEmpty) {
        _showSnack(
          'Codigo enviado al $label. Codigo de prueba: $preview',
        );
      } else {
        _showSnack('Codigo enviado al $label indicado.');
      }
    } catch (e) {
      _showSnack('No se pudo solicitar el codigo: $e');
    }
  }

  Widget _sheetSectionTitle(String title, Color muted) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: muted,
      ),
    );
  }

  Widget _sectionMiniTitle(String title, Color muted) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: muted,
        ),
      ),
    );
  }

  Widget _sheetCard({
    required Widget child,
    required Color cardColor,
    required Color borderColor,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.04,
            ),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: padding == null
          ? child
          : Padding(
              padding: padding,
              child: child,
            ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return SwitchListTile.adaptive(
      contentPadding:
          contentPadding ?? const EdgeInsets.symmetric(horizontal: 16),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      activeThumbColor: AppColors.brandBlue600,
      onChanged: onChanged,
    );
  }

  Widget _buildThemeTile({
    required String title,
    required String subtitle,
    required ThemeMode value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = _mutedColor(isDark);
    final registry = RadioGroup.maybeOf<ThemeMode>(context);

    return InkWell(
      onTap: registry == null ? null : () => registry.onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            Radio<ThemeMode>(
              value: value,
              activeColor: AppColors.brandBlue600,
            ),
          ],
        ),
      ),
    );
  }

  String _quietHoursSummary(QuietHours quietHours) {
    if (!quietHours.enabled || quietHours.days.isEmpty) {
      return 'Desactivado';
    }
    final range =
        '${_formatMinutes(quietHours.startMinutes)} - ${_formatMinutes(quietHours.endMinutes)}';
    final days = _formatDays(quietHours.days);
    return '$range - $days';
  }

  String _quietHoursStatus(QuietHours quietHours) {
    if (!quietHours.enabled || quietHours.days.isEmpty) return 'Desactivado';
    return quietHours.isActive(DateTime.now()) ? 'Activo ahora' : 'Inactivo';
  }

  String _formatMinutes(int minutes) {
    final hours = (minutes ~/ 60).toString().padLeft(2, '0');
    final mins = (minutes % 60).toString().padLeft(2, '0');
    return '$hours:$mins';
  }

  String _formatDays(List<int> days) {
    const labels = {
      1: 'Lun',
      2: 'Mar',
      3: 'Mie',
      4: 'Jue',
      5: 'Vie',
      6: 'Sab',
      7: 'Dom',
    };
    final sorted = [...days]..sort();
    return sorted.map((day) => labels[day] ?? '').join(', ');
  }

  TimeOfDay _minutesToTimeOfDay(int minutes) {
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  int _timeOfDayToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  String _inmuebleLabel(Inmueble inmueble) {
    final identificacion = inmueble.identificacion?.trim();
    if (identificacion != null && identificacion.isNotEmpty) {
      return identificacion;
    }
    final correlativo = inmueble.correlativo?.trim();
    if (correlativo != null && correlativo.isNotEmpty) {
      return 'Inmueble $correlativo';
    }
    final torre = inmueble.torre?.trim();
    final piso = inmueble.piso?.trim();
    if (torre != null && torre.isNotEmpty && piso != null && piso.isNotEmpty) {
      return 'Torre $torre - Piso $piso';
    }
    final nombre = inmueble.nombreCondominio?.trim();
    if (nombre != null && nombre.isNotEmpty) {
      return nombre;
    }
    return 'Inmueble ${inmueble.idInmueble}';
  }

  Widget _sheetHandle(Color muted) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: muted.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Color _cardColor(bool isDark) =>
      isDark ? AppColors.darkSurface : AppColors.surface;

  Color _borderColor(bool isDark) =>
      isDark ? AppColors.darkBorder : AppColors.border;

  Color _mutedColor(bool isDark) =>
      isDark ? AppColors.darkTextMuted : AppColors.textMuted;

  Widget _buildInputLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _mutedColor(isDark),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    TextInputType type, {
    bool obscure = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = _borderColor(isDark);
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      style: TextStyle(color: theme.colorScheme.onSurface),
      cursorColor: AppColors.brandBlue600,
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.brandBlue600,
            width: 1.4,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600),
        labelStyle: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
      ),
    );
  }
}

enum ContactKind { email, phone }
