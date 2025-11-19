import 'package:flutter/material.dart';

class UserScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const UserScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final usuario = userData['usuario'];
    final token = userData['token'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Datos del Usuario"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Información de la cuenta",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            _infoRow("ID", usuario["id"].toString()),
            _infoRow("Nombre", usuario["nombre"]),
            _infoRow("Correo", usuario["correo"]),
            _infoRow("Usuario (correo)", usuario["user"]),
            _infoRow("Perfil", usuario["perfil"]),

            const SizedBox(height: 30),
            const Text(
              "Token:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            SelectableText(
              token,
              style: const TextStyle(fontSize: 14, color: Colors.deepPurple),
            ),

            const Spacer(),

            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Cerrar sesión", style: TextStyle(fontSize: 18)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            "$label:",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
