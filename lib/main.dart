import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/user_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const VecinusApp());
}

class VecinusApp extends StatefulWidget {
  const VecinusApp({super.key});

  @override
  State<VecinusApp> createState() => _VecinusAppState();
}

class _VecinusAppState extends State<VecinusApp> {
  bool loading = true;
  bool loggedIn = false;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    loggedIn = await AuthService.isLoggedIn();
    if (loggedIn) {
      userData = {
        "usuario": await AuthService.getUser(),
        "token": await AuthService.getToken(),
      };
    }
    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: loggedIn
          ? UserScreen(userData: userData!)
          : const LoginScreen(),
    );
  }
}
