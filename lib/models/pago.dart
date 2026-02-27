class Pago {
  final String id;
  final String? descripcion;
  final String? fecha;
  final String? fechaVencimiento;
  final String? fechaEmision;
  final String? monto;
  final String? estado;
  final String? documentoUrl;
  final String? reciboUrl;
  final String? notificacionUrl;
  final String? token;

  Pago({
    required this.id,
    this.descripcion,
    this.fecha,
    this.fechaVencimiento,
    this.fechaEmision,
    this.monto,
    this.estado,
    this.documentoUrl,
    this.reciboUrl,
    this.notificacionUrl,
    this.token,
  });

  factory Pago.fromJson(Map<String, dynamic> json) {
    String? pickValue(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return null;
    }

    return Pago(
      id: (json['id_pago'] ?? json['id'] ?? '').toString(),
      descripcion: json['descripcion']?.toString(),
      fecha: json['fecha']?.toString(),
      fechaVencimiento: json['fecha_vencimiento']?.toString(),
      fechaEmision: json['fecha_emision']?.toString(),
      monto: json['monto']?.toString(),
      estado: json['estado']?.toString(),
      documentoUrl: pickValue(['documento_url', 'documento', 'document_url']),
      reciboUrl: pickValue(['recibo_url', 'recibo']),
      notificacionUrl: pickValue(['notificacion_url']),
      token: pickValue(['token']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_pago': id,
      'descripcion': descripcion,
      'fecha': fecha,
      'fecha_vencimiento': fechaVencimiento,
      'fecha_emision': fechaEmision,
      'monto': monto,
      'estado': estado,
      'documento_url': documentoUrl,
      'recibo_url': reciboUrl,
      'notificacion_url': notificacionUrl,
      'token': token,
    };
  }
}
