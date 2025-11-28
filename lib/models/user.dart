class User {
  final String id;
  final String nombre;
  final String apellido;
  final String correo;

  User({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.correo,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id_usuario'].toString(),
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      correo: json['correo'] ?? '',
    );
  }
}
