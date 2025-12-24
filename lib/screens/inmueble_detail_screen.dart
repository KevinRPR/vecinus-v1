import 'package:flutter/material.dart';

import '../models/inmueble.dart';
import '../models/pago.dart';

class InmuebleDetailScreen extends StatelessWidget {
  final Inmueble inmueble;

  const InmuebleDetailScreen({Key? key, required this.inmueble})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(inmueble.identificacion ?? 'Detalle del inmueble'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff203047),
        elevation: 1,
      ),
      backgroundColor: const Color(0xfff3f4f6),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('Resumen'),
          _infoTile('Estado', _estadoLabel(inmueble.estado)),
          _infoTile('Tipo', _valueOrDash(inmueble.tipo)),
          _infoTile('Direccion', _direccion(inmueble)),
          const SizedBox(height: 24),
          _sectionTitle('Identificadores'),
          _infoTile('ID inmueble', inmueble.idInmueble),
          _infoTile('Condominio', inmueble.idCondominio),
          _infoTile('Propietario', inmueble.idUsuario),
          _infoTile('Correlativo', _valueOrDash(inmueble.correlativo)),
          _infoTile('Alicuota', _valueOrDash(inmueble.alicuota)),
          const SizedBox(height: 24),
          _sectionTitle('Tiempos'),
          _infoTile('Creado', _valueOrDash(inmueble.fechaCreacion)),
          _infoTile('Actualizado', _valueOrDash(inmueble.fechaActualizacion)),
          _infoTile('Proximo pago', _proximaFechaPago()),
          const SizedBox(height: 24),
          _sectionTitle('Finanzas'),
          _infoTile('Deuda actual', _formatMonto(inmueble.deudaActual)),
          const SizedBox(height: 12),
          _pagosButton(context),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xff203047),
        ),
      ),
    );
  }

  Widget _infoTile(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xff203047),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pagosButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showPagosSheet(context),
      icon: const Icon(Icons.receipt_long),
      label: Text(
        inmueble.pagos.isEmpty
            ? 'Consultar historial (sin registros)'
            : 'Ver historial de pagos',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xff203047),
        side: const BorderSide(color: Color(0xff203047)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
    );
  }

  void _showPagosSheet(BuildContext context) {
    final pagos = inmueble.pagos;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.75,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Historial de pagos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff203047),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (pagos.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Aun no se registran pagos para este inmueble.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: pagos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) => _pagoTile(pagos[index]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pagoTile(Pago pago) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pago.descripcion ?? 'Pago ${pago.id}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xff203047),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Fecha: ${_formatDate(pago.fecha)}',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Monto: ${_formatMonto(pago.monto)}',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Estado: ${_valueOrDash(pago.estado)}',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String _estadoLabel(EstadoInmueble estado) {
    switch (estado) {
      case EstadoInmueble.alDia:
        return 'Al dia';
      case EstadoInmueble.pendiente:
        return 'Pendiente';
      case EstadoInmueble.moroso:
        return 'Moroso';
      default:
        return 'Desconocido';
    }
  }

  String _direccion(Inmueble i) {
    if (i.tipo?.toLowerCase() == 'apartamento') {
      return 'Torre ${_valueOrDash(i.torre)}, Piso ${_valueOrDash(i.piso)}';
    }
    return 'Calle ${_valueOrDash(i.calle)}, Mz ${_valueOrDash(i.manzana)}, Casa ${_valueOrDash(i.identificacion)}';
  }

  String _proximaFechaPago() {
    return _formatDate(inmueble.proximaFechaPago);
  }

  String _valueOrDash(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '--';
    }
    return value;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '--';
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  String _formatMonto(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '--';
    }
    final sanitized =
        raw.replaceAll(RegExp(r'[^0-9.,-]'), '').replaceAll(',', '.');
    final value = double.tryParse(sanitized);
    if (value == null) {
      return raw;
    }
    return '\$${value.toStringAsFixed(2)}';
  }
}
