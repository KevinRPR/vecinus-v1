import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 🌐 Dominio real de tu API
  static const String baseUrl = 'https://rhodiumdev.com/condominio/movil/';

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/login.php');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Error desconocido');
      }
    } else {
      throw Exception('Error HTTP ${response.statusCode}');
    }
  }
}
