import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/theme_controller.dart';

class UserScreen extends StatefulWidget {
  final User user;
  final String token;
  final bool embedded;
  final ValueChanged<User>? onUserUpdated;

  const UserScreen({
    super.key,
    required this.user,
    required this.token,
    this.embedded = false,
    this.onUserUpdated,
  });

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
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

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.user.nombre);
    _apellidoController = TextEditingController(text: widget.user.apellido);
    _correoController = TextEditingController(text: widget.user.correo);
    _user = widget.user;
    _loadProfile();
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

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final remoteUser = await ApiService.fetchProfile(widget.token);
      final sessionAware = remoteUser.copyWith(
        sessionExpiresAt: _user?.sessionExpiresAt ?? widget.user.sessionExpiresAt,
      );
      setState(() {
        _user = sessionAware;
        _nombreController.text = sessionAware.nombre;
        _apellidoController.text = sessionAware.apellido;
        _correoController.text = sessionAware.correo;
        _loading = false;
      });
      widget.onUserUpdated?.call(sessionAware);
    } catch (e) {
      _showSnack('No se pudo sincronizar el perfil: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final nombre = _nombreController.text.trim();
    final apellido = _apellidoController.text.trim();
    final correo = _correoController.text.trim();

    if (nombre.isEmpty || apellido.isEmpty) {
      _showSnack('Completa tu nombre y apellido.');
      return;
    }
    if (!_isValidEmail(correo)) {
      _showSnack('El correo no parece valido.');
      return;
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
        sessionExpiresAt: _user?.sessionExpiresAt ?? widget.user.sessionExpiresAt,
      );

      await AuthService.saveSession(widget.token, sessionAware.toJson());

      setState(() => _user = sessionAware);
      widget.onUserUpdated?.call(sessionAware);
      _showSnack('Datos actualizados.');
    } catch (e) {
      _showSnack('Error al actualizar: $e');
    } finally {
      setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final actual = _passwordActualController.text;
    final nueva = _passwordNuevaController.text;
    final confirm = _passwordConfirmController.text;

    if (actual.isEmpty || nueva.isEmpty || confirm.isEmpty) {
      _showSnack('Completa todos los campos de contrasena.');
      return;
    }
    if (nueva.length < 6) {
      _showSnack('La contrasena nueva debe tener al menos 6 caracteres.');
      return;
    }
    if (nueva != confirm) {
      _showSnack('La confirmacion no coincide.');
      return;
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
    } catch (e) {
      _showSnack('No se pudo actualizar la contrasena: $e');
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
          sessionExpiresAt: _user?.sessionExpiresAt ?? widget.user.sessionExpiresAt,
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
    final scaffold = Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mi perfil'),
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  final user = _user ?? widget.user;
                  widget.onUserUpdated?.call(user);
                  Navigator.pop(context, user);
                },
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _profileHeader(context),
                  const SizedBox(height: 24),
                  _sectionCard(
                    context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputLabel('Nombre'),
                        _buildTextField(_nombreController, TextInputType.name),
                        const SizedBox(height: 16),
                        _buildInputLabel('Apellido'),
                        _buildTextField(_apellidoController, TextInputType.name),
                        const SizedBox(height: 16),
                        _buildInputLabel('Correo'),
                        _buildTextField(
                          _correoController,
                          TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _savingProfile ? null : _saveProfile,
                            child: _savingProfile
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Guardar cambios'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Seguridad',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _sectionCard(
                    context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputLabel('Contrasena actual'),
                        _buildTextField(
                          _passwordActualController,
                          TextInputType.visiblePassword,
                          obscure: true,
                        ),
                        const SizedBox(height: 16),
                        _buildInputLabel('Nueva contrasena'),
                        _buildTextField(
                          _passwordNuevaController,
                          TextInputType.visiblePassword,
                          obscure: true,
                        ),
                        const SizedBox(height: 16),
                        _buildInputLabel('Confirmar contrasena'),
                        _buildTextField(
                          _passwordConfirmController,
                          TextInputType.visiblePassword,
                          obscure: true,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _changingPassword ? null : _changePassword,
                            child: _changingPassword
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Actualizar contrasena'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ajustes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _sectionCard(
                    context,
                    child: _buildSettingsSection(context),
                  ),
                ],
              ),
            ),
    );

    if (widget.embedded) {
      return scaffold;
    }

    return WillPopScope(
      onWillPop: () async {
        final user = _user ?? widget.user;
        widget.onUserUpdated?.call(user);
        Navigator.pop(context, user);
        return false;
      },
      child: scaffold,
    );
  }

  Widget _profileHeader(BuildContext context) {
    final avatarUrl = _user?.avatarUrl;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradientColors = isDark
        ? const [Color(0xff1f2937), Color(0xff0f172a)]
        : const [Color(0xfff9fafb), Color(0xffeef2ff)];
    final circleBg = isDark ? const Color(0xff243447) : const Color(0xffe2e8f0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 55,
                backgroundColor: circleBg,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person, size: 50, color: Colors.white70)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: _uploadingAvatar ? null : _pickAvatar,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xff1d9bf0),
                    child: _uploadingAvatar
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            (_user ?? widget.user).displayName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _user?.correo ?? widget.user.correo,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (context, controller, _) {
        final platformDark =
            MediaQuery.of(context).platformBrightness == Brightness.dark;
        final mode = controller.themeMode;
        final isDark = mode == ThemeMode.dark ||
            (mode == ThemeMode.system && platformDark);
        final followsSystem = mode == ThemeMode.system;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile.adaptive(
              value: isDark,
              onChanged: (value) {
                final nextMode = value ? ThemeMode.dark : ThemeMode.light;
                controller.setThemeMode(nextMode);
              },
              contentPadding: EdgeInsets.zero,
              title: const Text('Modo oscuro'),
              subtitle: Text(
                followsSystem
                    ? 'Siguiendo el tema del sistema.'
                    : (isDark
                        ? 'Modo oscuro activado.'
                        : 'Modo claro activado.'),
              ),
            ),
            if (!followsSystem)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => controller.resetToSystem(),
                  child: const Text('Usar modo del sistema'),
                ),
              )
            else
              Text(
                'Por defecto adoptamos el modo que tenga tu dispositivo.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withOpacity(0.8),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xff475467),
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
    final fill = isDark ? const Color(0xff1f2b3a) : const Color(0xffeef2ff);
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      decoration: InputDecoration(
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
