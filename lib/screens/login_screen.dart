import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> login() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await ApiService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      final token = data['token'];
      final userJson = data['usuario'];
      final user = User.fromJson(userJson);
      final sessionExpiration =
          DateTime.now().add(const Duration(minutes: 10));
      final sessionUser = user.copyWith(sessionExpiresAt: sessionExpiration);

      await AuthService.saveSession(token, sessionUser.toJson());

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainShell(user: sessionUser, token: token),
          ),
        );
      }
    } catch (e) {
      String message = e.toString();

      if (message.contains('401')) {
        message = 'Credenciales incorrectas.';
      } else if (message.contains('403')) {
        message = 'Usuario inactivo.';
      }

      setState(() => error = message);
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    TextInputType type = TextInputType.text,
  }) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final fieldColor =
        isDark ? const Color(0xff1f2b3a) : const Color(0xffeef2ff);
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: fieldColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Bienvenido a Vecinus',
                  style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ingresa con tu correo y contraseña para continuar.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor?.withOpacity(
                              theme.brightness == Brightness.dark ? 0.4 : 0.12,
                            ) ??
                            Colors.black.withOpacity(0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(
                        controller: emailController,
                        label: 'Correo electrónico',
                        type: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: passwordController,
                        label: 'Contraseña',
                        obscure: true,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '¿Olvidaste tu contraseña?',
                  style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            error!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading ? null : login,
                          child: loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Iniciar sesión'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Necesitas ayuda?',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Contacta al administrador',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
