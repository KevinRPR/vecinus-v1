import 'package:flutter/material.dart';

import '../models/inmueble.dart';
import '../models/pago.dart';

class InmuebleDetailScreen extends StatelessWidget {
  final Inmueble inmueble;

  const InmuebleDetailScreen({super.key, required this.inmueble});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(inmueble.identificacion ?? 'Detalle del inmueble'),
        elevation: 1,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle(context, 'Resumen'),
          _infoTile(context, 'Estado', _estadoLabel(inmueble.estado)),
          _infoTile(context, 'Tipo', _valueOrDash(inmueble.tipo)),
          _infoTile(context, 'Direccion', _direccion(inmueble)),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Identificadores'),
          _infoTile(context, 'ID inmueble', inmueble.idInmueble),
          _infoTile(context, 'Condominio', inmueble.idCondominio),
          _infoTile(context, 'Propietario', inmueble.idUsuario),
          _infoTile(context, 'Correlativo', _valueOrDash(inmueble.correlativo)),
          _infoTile(context, 'Alicuota', _valueOrDash(inmueble.alicuota)),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Tiempos'),
          _infoTile(context, 'Creado', _valueOrDash(inmueble.fechaCreacion)),
          _infoTile(
            context,
            'Actualizado',
            _valueOrDash(inmueble.fechaActualizacion),
          ),
          _infoTile(context, 'Proximo pago', _proximaFechaPago()),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Finanzas'),
          _infoTile(context, 'Deuda actual', _formatMonto(inmueble.deudaActual)),
          const SizedBox(height: 12),
          _pagosButton(context),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _infoTile(BuildContext context, String title, String value) {
    final theme = Theme.of(context);
    final muted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
            theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final shadowColor = Colors.black.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.25 : 0.05,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: muted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pagosButton(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: () => _showPagosSheet(context),
      icon: const Icon(Icons.receipt_long),
      label: Text(
        inmueble.pagos.isEmpty
            ? 'Consultar historial (sin registros)'
            : 'Ver historial de pagos',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        side: BorderSide(color: theme.colorScheme.primary),
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
        final theme = Theme.of(context);
        final muted =
            theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75) ??
                theme.colorScheme.onSurface.withValues(alpha: 0.6);
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
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Historial de pagos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
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
                            color: muted,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: pagos.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) => _pagoTile(context, pagos[index]),
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

  Widget _pagoTile(BuildContext context, Pago pago) {
    final theme = Theme.of(context);
    final muted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75) ??
            theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final shadowColor = Colors.black.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.25 : 0.05,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Fecha: ${_formatDate(pago.fecha)}',
            style: TextStyle(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 4),
          Text(
            'Monto: ${_formatMonto(pago.monto)}',
            style: TextStyle(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 4),
          Text(
            'Estado: ${_valueOrDash(pago.estado)}',
            style: TextStyle(fontSize: 13, color: muted),
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
