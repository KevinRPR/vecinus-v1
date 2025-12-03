class User {
  final String id;
  final String nombre;
  final String apellido;
  final String correo;
  final String? avatarUrl;
  final DateTime? sessionExpiresAt;

  const User({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.correo,
    this.avatarUrl,
    this.sessionExpiresAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final rawId = json['id_usuario'] ?? json['id'] ?? json['user_id'] ?? '';
    var firstName = (json['nombre'] ?? '').toString();
    var lastName = (json['apellido'] ?? '').toString();

    if (lastName.isEmpty && firstName.contains(' ')) {
      final parts = firstName.split(' ');
      firstName = parts.first;
      lastName = parts.sublist(1).join(' ');
    }

    final correo = (json['correo'] ?? json['email'] ?? '').toString();
    DateTime? expires;
    final rawExpiry = json['session_expires_at'];

    if (rawExpiry is String && rawExpiry.isNotEmpty) {
      expires = DateTime.tryParse(rawExpiry);
    } else if (rawExpiry is int) {
      expires = DateTime.fromMillisecondsSinceEpoch(rawExpiry);
    }

    return User(
      id: rawId.toString(),
      nombre: firstName,
      apellido: lastName,
      correo: correo,
      avatarUrl: json['avatar_url']?.toString(),
      sessionExpiresAt: expires,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_usuario': id,
      'nombre': nombre,
      'apellido': apellido,
      'correo': correo,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (sessionExpiresAt != null)
        'session_expires_at': sessionExpiresAt!.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? nombre,
    String? apellido,
    String? correo,
    String? avatarUrl,
    DateTime? sessionExpiresAt,
  }) {
    return User(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      correo: correo ?? this.correo,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      sessionExpiresAt: sessionExpiresAt ?? this.sessionExpiresAt,
    );
  }

  bool get hasValidSession {
    if (sessionExpiresAt == null) return false;
    return DateTime.now().isBefore(sessionExpiresAt!);
  }

  String get displayName {
    final buffer = <String>[];
    if (nombre.trim().isNotEmpty) buffer.add(nombre.trim());
    if (apellido.trim().isNotEmpty) buffer.add(apellido.trim());
    return buffer.isEmpty ? correo : buffer.join(' ');
  }
}
