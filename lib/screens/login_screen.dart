import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'user_screen.dart';  // 👈 Importa la pantalla de usuario

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

      // 👉 Guardar token (más adelante podemos usar SharedPreferences)
      final token = data['token'];
      print('Token recibido: $token');

      // 👉 Navegar a la pantalla que muestra los datos del usuario
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserScreen(userData: data),
          ),
        );
      }

    } catch (e) {
      // MEJORAR el mensaje de error
      String message = e.toString();

      if (message.contains("401")) {
        message = "Credenciales incorrectas o usuario no encontrado.";
      } else if (message.contains("403")) {
        message = "El usuario está inactivo.";
      } else if (message.contains("500")) {
        message = "Error interno del servidor.";
      }

      setState(() {
        error = message;
      });

    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Correo electrónico'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
            ),
            const SizedBox(height: 24),

            if (error != null)
              Text(
                error!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: loading ? null : login,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
