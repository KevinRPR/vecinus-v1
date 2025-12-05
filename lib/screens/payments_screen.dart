import 'package:flutter/material.dart';

import '../models/inmueble.dart';

class PaymentsScreen extends StatelessWidget {
  final List<Inmueble> inmuebles;
  final bool loading;
  final Future<void> Function() onRefresh;

  const PaymentsScreen({
    super.key,
    required this.inmuebles,
    required this.loading,
    required this.onRefresh,
  });

  double get totalDeuda => inmuebles.fold(
        0,
        (sum, i) =>
            sum +
            (double.tryParse((i.deudaActual ?? '').replaceAll(',', '.')) ?? 0),
      );

  List<_HistorialPago> get _historial {
    final List<_HistorialPago> history = [];
    for (final inmueble in inmuebles) {
      for (final pago in inmueble.pagos) {
        history.add(
          _HistorialPago(
            inmueble: inmueble.identificacion ?? inmueble.idInmueble,
            descripcion: pago.descripcion ?? 'Pago',
            fecha: pago.fecha ?? '',
            monto: pago.monto ?? '',
            estado: pago.estado ?? '',
          ),
        );
      }
    }
    history.sort((a, b) => b.fecha.compareTo(a.fecha));
    return history.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Pagos'),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  _summaryCard(theme),
                  const SizedBox(height: 24),
                  Text(
                    'Detalle por inmueble',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (inmuebles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Sin inmuebles registrados.'),
                    )
                  else
                    ...inmuebles.map((inmueble) => _inmuebleTile(inmueble, theme)),
                  const SizedBox(height: 32),
                  Text(
                    'Historial reciente',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (_historial.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Aun no hay pagos registrados.'),
                    )
                  else
                    ..._historial.map((pago) => _historialTile(pago, theme)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(ThemeData theme) {
    final subtle =
        theme.textTheme.bodyMedium?.color?.withOpacity(0.65) ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (theme.shadowColor ?? Colors.black.withOpacity(0.1))
                .withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total adeudado',
                  style: TextStyle(color: subtle),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatCurrency(totalDeuda),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${inmuebles.length} inmuebles',
                  style: TextStyle(color: subtle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pie_chart_rounded,
              size: 32,
              color: theme.colorScheme.primary,
            ),
          )
        ],
      ),
    );
  }

  Widget _inmuebleTile(Inmueble inmueble, ThemeData theme) {
    final deuda =
        double.tryParse((inmueble.deudaActual ?? '').replaceAll(',', '.')) ?? 0;
    final subtle =
        theme.textTheme.bodyMedium?.color?.withOpacity(0.65) ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (theme.shadowColor ?? Colors.black.withOpacity(0.1))
                .withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.home_work_outlined,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inmueble.identificacion ?? 'Inmueble',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      inmueble.tipo ?? 'Propiedad',
                      style: TextStyle(color: subtle),
                    ),
                  ],
                ),
              ),
              _badgeEstado(inmueble.estado),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deuda',
                    style: TextStyle(color: subtle),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(deuda),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Proximo pago',
                    style: TextStyle(color: subtle),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    inmueble.proximaFechaPago ?? '--',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          if (inmueble.pagos.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Historial',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Column(
              children: inmueble.pagos
                  .take(3)
                  .map(
                    (pago) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pago.fecha ?? '--',
                          style: TextStyle(color: subtle),
                        ),
                        Text(
                          '\$${pago.monto ?? '--'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badgeEstado(EstadoInmueble estado) {
    Color color;
    String texto;

    switch (estado) {
      case EstadoInmueble.alDia:
        color = const Color(0xff16a34a);
        texto = 'Al dia';
        break;
      case EstadoInmueble.pendiente:
        color = const Color(0xfff59e0b);
        texto = 'Pendiente';
        break;
      case EstadoInmueble.moroso:
        color = const Color(0xffef4444);
        texto = 'Moroso';
        break;
      default:
        color = Colors.blueGrey;
        texto = 'N/D';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        texto,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Widget _historialTile(_HistorialPago pago, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (theme.shadowColor ?? Colors.black.withOpacity(0.1))
                .withOpacity(theme.brightness == Brightness.dark ? 0.25 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_long, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pago.descripcion,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${pago.fecha} - ${pago.inmueble}',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.65),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${pago.monto}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                pago.estado,
                style: TextStyle(
                  color: pago.estado.toLowerCase().contains('pend')
                      ? const Color(0xfff59e0b)
                      : const Color(0xff16a34a),
                  fontSize: 12,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  String _formatCurrency(double value) => '\$${value.toStringAsFixed(2)}';
}

class _HistorialPago {
  final String inmueble;
  final String descripcion;
  final String fecha;
  final String monto;
  final String estado;

  _HistorialPago({
    required this.inmueble,
    required this.descripcion,
    required this.fecha,
    required this.monto,
    required this.estado,
  });
}




