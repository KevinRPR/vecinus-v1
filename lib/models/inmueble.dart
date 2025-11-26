class Inmueble {
  final int id;
  final String tipo;       // casa o apartamento
  final String nombreMostrar;
  final String condominio;
  final double alicuota;

  Inmueble({
    required this.id,
    required this.tipo,
    required this.nombreMostrar,
    required this.condominio,
    required this.alicuota,
  });

  factory Inmueble.fromJson(Map<String, dynamic> json) {
    return Inmueble(
      id: int.parse(json["id_inmueble"].toString()),
      tipo: json["tipo"] ?? "",
      nombreMostrar: json["nombre_mostrar"] ?? "",
      condominio: json["condominio"] ?? "",
      alicuota: double.tryParse(json["alicuota"].toString()) ?? 0,
    );
  }
}
