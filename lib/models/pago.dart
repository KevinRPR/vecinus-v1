class Pago {
  final String id;
  final String? descripcion;
  final String? fecha;
  final String? monto;
  final String? estado;

  Pago({
    required this.id,
    this.descripcion,
    this.fecha,
    this.monto,
    this.estado,
  });

  factory Pago.fromJson(Map<String, dynamic> json) {
    return Pago(
      id: (json['id_pago'] ?? json['id'] ?? '').toString(),
      descripcion: json['descripcion']?.toString(),
      fecha: json['fecha']?.toString(),
      monto: json['monto']?.toString(),
      estado: json['estado']?.toString(),
    );
  }
}
