class PaymentReport {
  final String id;
  final String idInmueble;
  final String idCondominio;
  final String fechaPago;
  final String? observacion;
  final double totalBase;
  final int? monedaBase;
  final String estado;
  final String? motivoRechazo;
  final String? evidenciaUrl;
  final DateTime? createdAt;
  final DateTime? aprobadoAt;
  final DateTime? rechazadoAt;
  final String? clientUuid;
  final double? abonoTotalBase;
  final double? pagosTotalBase;
  final double? pendienteTotalBase;
  final bool? cubreTotalEstimado;

  PaymentReport({
    required this.id,
    required this.idInmueble,
    required this.idCondominio,
    required this.fechaPago,
    this.observacion,
    required this.totalBase,
    this.monedaBase,
    required this.estado,
    this.motivoRechazo,
    this.evidenciaUrl,
    this.createdAt,
    this.aprobadoAt,
    this.rechazadoAt,
    this.clientUuid,
    this.abonoTotalBase,
    this.pagosTotalBase,
    this.pendienteTotalBase,
    this.cubreTotalEstimado,
  });

  factory PaymentReport.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      return double.tryParse(v.toString());
    }

    return PaymentReport(
      id: json['id'].toString(),
      idInmueble: json['id_inmueble']?.toString() ?? '',
      idCondominio: json['id_condominio']?.toString() ?? '',
      fechaPago: json['fecha_pago']?.toString() ?? '',
      observacion: json['observacion']?.toString(),
      totalBase: double.tryParse(json['total_base']?.toString() ?? '') ?? 0,
      monedaBase: json['moneda_base'] is int
          ? json['moneda_base'] as int
          : int.tryParse(json['moneda_base']?.toString() ?? ''),
      estado: (json['estado'] ?? '').toString().toUpperCase(),
      motivoRechazo: json['motivo_rechazo']?.toString(),
      evidenciaUrl: json['evidencia_url']?.toString(),
      createdAt: parseDate(json['created_at']),
      aprobadoAt: parseDate(json['aprobado_at']),
      rechazadoAt: parseDate(json['rechazado_at']),
      clientUuid: json['client_uuid']?.toString(),
      abonoTotalBase: parseDouble(json['abono_total_base']),
      pendienteTotalBase: parseDouble(json['pendiente_total_base']),
      pagosTotalBase: parseDouble(json['pagos_total_base']),
      cubreTotalEstimado: json['cubre_total_estimado'] is bool
          ? json['cubre_total_estimado'] as bool
          : (json['cubre_total_estimado']?.toString().toLowerCase() == 'true'),
    );
  }
}
