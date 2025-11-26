import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const VecinusApp());
}

class VecinusApp extends StatelessWidget {
  const VecinusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Vecinus App",
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const SplashScreen(),
    );
  }
}