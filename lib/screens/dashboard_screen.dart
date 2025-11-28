import 'package:flutter/material.dart';
import '../models/inmueble.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'user_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User user;
  final String token;

  DashboardScreen({required this.user, required this.token});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Inmueble> inmuebles = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    cargarInmuebles();
  }

  Future<void> cargarInmuebles() async {
    try {
      final data = await ApiService.getMisInmuebles(widget.token);
      setState(() {
        inmuebles = data;
        loading = false;
      });
    } catch (e) {
      print("Error cargando inmuebles: $e");
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff3f4f6),

      // 🔹 BARRA SUPERIOR (BOTÓN DE PERFIL)
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.person, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserScreen(
                    userData: {
                      "usuario": {
                        "id_usuario": widget.user.id,
                        "nombre": widget.user.nombre,
                        "apellido": widget.user.apellido,
                        "correo": widget.user.correo,
                      },
                      "token": widget.token,
                    },
                  ),
                ),
              );
            },
          )
        ],
      ),

      body: loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 10),

                  // 🔹 SALUDO PRINCIPAL
                  Text(
                    "Hola, ${widget.user.nombre} 👋",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff203047),
                    ),
                  ),

                  SizedBox(height: 6),

                  Text(
                    "Aquí están tus inmuebles:",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),

                  SizedBox(height: 20),

                  // 🔹 LISTA DE INMUEBLES DIRECTA
                  if (inmuebles.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Text(
                          "No tienes inmuebles registrados",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: inmuebles
                          .map((i) => _buildInmuebleCard(i))
                          .toList(),
                    ),
                ],
              ),
            ),
    );
  }

  // 🔹 CARD DE INMUEBLE
  Widget _buildInmuebleCard(Inmueble i) {
    return Container(
      margin: EdgeInsets.only(bottom: 18),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          )
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                i.identificacion ?? "Inmueble",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff203047),
                ),
              ),
              _badgeEstado(i.estado),
            ],
          ),

          SizedBox(height: 8),

          Text(
            _direccion(i),
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),

          SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff203047),
                padding: EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                // Pantalla de detalle (próximo módulo)
              },
              child: Text("Ver inmueble"),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 ESTADO DEL INMUEBLE (USA EL ENUM)
  Widget _badgeEstado(EstadoInmueble estado) {
    Color color;
    String texto;

    switch (estado) {
      case EstadoInmueble.alDia:
        color = Colors.green;
        texto = "AL DÍA";
        break;

      case EstadoInmueble.pendiente:
        color = Colors.orange;
        texto = "PENDIENTE";
        break;

      case EstadoInmueble.moroso:
        color = Colors.red;
        texto = "MOROSO";
        break;

      default:
        color = Colors.blueGrey;
        texto = "DESCONOCIDO";
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        texto,
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  // 🔹 DIRECCIÓN inteligente
  String _direccion(Inmueble i) {
    if (i.tipo == "apartamento") {
      return "Torre ${i.torre}, Piso ${i.piso}";
    }
    return "Calle ${i.calle}, Mz ${i.manzana}, Casa ${i.identificacion}";
  }
}
