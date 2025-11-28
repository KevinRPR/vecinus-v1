import 'package:flutter/material.dart';
import '../models/user.dart';
import 'dashboard_screen.dart';

class UserScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const UserScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final user = User.fromJson(userData['usuario']);

    return Scaffold(
      appBar: AppBar(
        title: Text("Mi Perfil"),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              "Bienvenido, ${user.nombre} ${user.apellido}",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 20),

            Text("Correo: ${user.correo}", style: TextStyle(fontSize: 16)),
            SizedBox(height: 6),

            Text("ID Usuario: ${user.id}", style: TextStyle(fontSize: 16)),
            SizedBox(height: 20),

            SizedBox(height: 30),

            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DashboardScreen(
                        user: user,
                        token: userData['token'],
                      ),
                    ),
                  );
                },
                child: Text(
                  "Ir a Mis Inmuebles",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
