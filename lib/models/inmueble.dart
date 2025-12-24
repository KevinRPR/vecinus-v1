import 'pago.dart';

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
  final String? nombreCondominio;
  final String? proximaFechaPago;
  final String? deudaActual;
  final List<Pago> pagos;

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
    this.nombreCondominio,
    this.proximaFechaPago,
    this.deudaActual,
    List<Pago>? pagos,
  }) : pagos = pagos ?? <Pago>[];

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
      nombreCondominio: json['condominio_nombre']?.toString() ??
          json['nombre_condominio']?.toString() ??
          json['condominio']?.toString(),
      proximaFechaPago: json['proxima_fecha_pago']?.toString(),
      deudaActual: json['deuda_actual']?.toString(),
      pagos: _parsePagos(json['pagos']),
    );
  }

  static List<Pago> _parsePagos(dynamic rawPagos) {
    if (rawPagos is List) {
      return rawPagos
          .whereType<Map<String, dynamic>>()
          .map(Pago.fromJson)
          .toList();
    }
    return <Pago>[];
  }

  Map<String, dynamic> toJson() {
    return {
      'id_inmueble': idInmueble,
      'id_condominio': idCondominio,
      'id_usuario': idUsuario,
      'alicuota': alicuota,
      'estado': _estadoToInt(estado),
      'fecha_creacion': fechaCreacion,
      'fecha_actualizacion': fechaActualizacion,
      'correlativo': correlativo,
      'identificacion': identificacion,
      'torre': torre,
      'piso': piso,
      'manzana': manzana,
      'calle': calle,
      'avenida': avenida,
      'tipo': tipo,
      'condominio_nombre': nombreCondominio,
      'proxima_fecha_pago': proximaFechaPago,
      'deuda_actual': deudaActual,
      'pagos': pagos.map((p) => p.toJson()).toList(),
    };
  }

  int _estadoToInt(EstadoInmueble e) {
    switch (e) {
      case EstadoInmueble.alDia:
        return 1;
      case EstadoInmueble.pendiente:
        return 2;
      case EstadoInmueble.moroso:
        return 3;
      case EstadoInmueble.desconocido:
      default:
        return 0;
    }
  }

  static EstadoInmueble _parseEstado(dynamic raw) {
    if (raw == null) return EstadoInmueble.desconocido;

    // Caso booleano
    if (raw is bool) {
      return raw ? EstadoInmueble.alDia : EstadoInmueble.moroso;
    }

    // Caso numero entero
    if (raw is int) {
      switch (raw) {
        case 1:
          return EstadoInmueble.alDia;
        case 2:
          return EstadoInmueble.pendiente;
        case 3:
          return EstadoInmueble.moroso;
        case 0:
          return EstadoInmueble.desconocido;
      }
    }

    // Caso string
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
