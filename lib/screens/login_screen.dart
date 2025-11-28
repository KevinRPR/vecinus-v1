import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import 'dashboard_screen.dart';

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

      await AuthService.saveSession(token, userJson);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              user: user,
              token: token,
            ),
          ),
        );
      }

    } catch (e) {
      String message = e.toString();

      if (message.contains("401")) {
        message = "Credenciales incorrectas.";
      } else if (message.contains("403")) {
        message = "Usuario inactivo.";
      }

      setState(() => error = message);

    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),

            const SizedBox(height: 24),

            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: loading ? null : login,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Iniciar sesión"),
            ),
          ],
        ),
      ),
    );
  }
}
