import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/inmueble.dart';

class MisInmueblesScreen extends StatefulWidget {
  const MisInmueblesScreen({super.key});

  @override
  State<MisInmueblesScreen> createState() => _MisInmueblesScreenState();
}

class _MisInmueblesScreenState extends State<MisInmueblesScreen> {
  bool loading = true;
  String? error;
  List<Inmueble> inmuebles = [];

  @override
  void initState() {
    super.initState();
    _loadInmuebles();
  }

  Future<void> _loadInmuebles() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        setState(() {
          error = "Sesión expirada. Vuelva a iniciar sesión.";
        });
        return;
      }

      final data = await ApiService.getMisInmuebles(token);

      setState(() {
        inmuebles = data;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Inmuebles"),
        backgroundColor: Colors.deepPurple,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: inmuebles.length,
                  itemBuilder: (context, index) {
                    final inm = inmuebles[index];

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        title: Text(
                          inm.nombreMostrar,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Condominio: ${inm.condominio}\nAlícuota: ${inm.alicuota}%",
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          // Luego aquí enviamos a detalles
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
