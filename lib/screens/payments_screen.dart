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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  _summaryCard(),
                  const SizedBox(height: 24),
                  Text(
                    'Detalle por inmueble',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (inmuebles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Sin inmuebles registrados.'),
                    )
                  else
                    ...inmuebles.map(_inmuebleTile),
                  const SizedBox(height: 32),
                  Text(
                    'Historial reciente',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (_historial.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Aún no hay pagos registrados.'),
                    )
                  else
                    ..._historial.map(_historialTile),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total adeudado',
                  style: TextStyle(color: Colors.grey),
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
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          const Icon(
            Icons.pie_chart_rounded,
            size: 48,
            color: Color(0xff1d9bf0),
          ),
        ],
      ),
    );
  }

  Widget _inmuebleTile(Inmueble inmueble) {
    final deuda =
        double.tryParse((inmueble.deudaActual ?? '').replaceAll(',', '.')) ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.home_work_outlined, color: Color(0xff1d9bf0)),
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
                      style: TextStyle(color: Colors.grey.shade600),
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
                  const Text(
                    'Deuda',
                    style: TextStyle(color: Colors.grey),
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
                  const Text(
                    'Próximo pago',
                    style: TextStyle(color: Colors.grey),
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
                          style: TextStyle(color: Colors.grey.shade600),
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
        texto = 'Al día';
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

  Widget _historialTile(_HistorialPago pago) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: const Color(0xffe0f2fe),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long, color: Color(0xff0ea5e9)),
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
                  '${pago.fecha} • ${pago.inmueble}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
