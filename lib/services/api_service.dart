import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/inmueble.dart';

class ApiService {
  static const String baseUrl = 'https://rhodiumdev.com/condominio/movil/';

  // LOGIN
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('${baseUrl}login.php');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Error desconocido');
    }
  }

  // OBTENER INMUEBLES DEL USUARIO
  static Future<List<Inmueble>> getMisInmuebles(String token) async {
    final url = Uri.parse('${baseUrl}mis_inmuebles.php');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token}),
    );

    final data = jsonDecode(response.body);
    print("API inmuebles: $data");

    if (response.statusCode == 200 && data['success'] == true) {
      final List lista = data['inmuebles'];
      return lista.map((e) => Inmueble.fromJson(e)).toList();
    } else {
      throw Exception(data['error'] ?? 'Error desconocido');
    }
  }
}
