class Pago {
  final String id;
  final String? descripcion;
  final String? fecha;
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
    this.monto,
    this.estado,
    this.documentoUrl,
    this.reciboUrl,
    this.notificacionUrl,
    this.token,
  });

  factory Pago.fromJson(Map<String, dynamic> json) {
    String? _pick(List<String> keys) {
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
      monto: json['monto']?.toString(),
      estado: json['estado']?.toString(),
      documentoUrl: _pick(['documento_url', 'documento', 'document_url']),
      reciboUrl: _pick(['recibo_url', 'recibo']),
      notificacionUrl: _pick(['notificacion_url']),
      token: _pick(['token']),
    );
  }
}
