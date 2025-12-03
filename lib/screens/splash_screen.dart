import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'main_shell.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 800));

    final token = await AuthService.getToken();
    final userMap = await AuthService.getUser();

    if (!mounted) return;

    if (token != null && userMap != null) {
      final user = User.fromJson(userMap);

      if (user.hasValidSession) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainShell(user: user, token: token),
          ),
        );
        return;
      } else {
        await AuthService.logout();
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LOGO
            const Icon(
              Icons.apartment_rounded,
              size: 90,
              color: Colors.white,
            ),

            const SizedBox(height: 25),

            const Text(
              "Vecinus App",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 40),

            const CircularProgressIndicator(
              color: Colors.white,
            )
          ],
        ),
      ),
    );
  }
}
