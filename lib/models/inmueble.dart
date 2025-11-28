enum EstadoInmueble { alDia, pendiente, moroso, desconocido }

class Inmueble {
  final String idInmueble;
  final String idCondominio;
  final String idUsuario;
  final String? alicuota;
  final EstadoInmueble estado;
  final String? fechaCreacion;
  final String? fechaActualizacion;
  final String? correlativo;
  final String? identificacion; 
  final String? torre;
  final String? piso;
  final String? manzana;
  final String? calle;
  final String? avenida;
  final String? tipo;

  Inmueble({
    required this.idInmueble,
    required this.idCondominio,
    required this.idUsuario,
    required this.estado,
    this.alicuota,
    this.fechaCreacion,
    this.fechaActualizacion,
    this.correlativo,
    this.identificacion,
    this.torre,
    this.piso,
    this.manzana,
    this.calle,
    this.avenida,
    this.tipo,
  });

  factory Inmueble.fromJson(Map<String, dynamic> json) {
    return Inmueble(
      idInmueble: json['id_inmueble'].toString(),
      idCondominio: json['id_condominio'].toString(),
      idUsuario: json['id_usuario'].toString(),
      alicuota: json['alicuota']?.toString(),
      estado: _parseEstado(json['estado']),
      fechaCreacion: json['fecha_creacion'],
      fechaActualizacion: json['fecha_actualizacion'],
      correlativo: json['correlativo']?.toString(),
      identificacion: json['identificacion'],
      torre: json['torre'],
      piso: json['piso'],
      manzana: json['manzana'],
      calle: json['calle'],
      avenida: json['avenida'],
      tipo: json['tipo'],
    );
  }

  static EstadoInmueble _parseEstado(dynamic raw) {
    if (raw == null) return EstadoInmueble.desconocido;

    // 🔹 Caso booleano
    if (raw is bool) {
      return raw ? EstadoInmueble.alDia : EstadoInmueble.moroso;
    }

    // 🔹 Caso número entero
    if (raw is int) {
      switch (raw) {
        case 1:
          return EstadoInmueble.alDia;
        case 2:
          return EstadoInmueble.pendiente;
        case 3:
          return EstadoInmueble.moroso;
      }
    }

    // 🔹 Caso string
    final value = raw.toString().toLowerCase();

    if (value == "true" || value == "1" || value == "t") {
      return EstadoInmueble.alDia;
    }
    if (value == "false" || value == "0" || value == "f") {
      return EstadoInmueble.moroso;
    }
    if (value == "2") {
      return EstadoInmueble.pendiente;
    }
    if (value == "3") {
      return EstadoInmueble.moroso;
    }

    return EstadoInmueble.desconocido;
  }
}
