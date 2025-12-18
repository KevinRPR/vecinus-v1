import 'package:flutter/material.dart';

import '../animations/shimmers.dart';
import '../animations/stagger_list.dart';
import '../models/inmueble.dart';
import 'payment_detail_screen.dart';

class PaymentsScreen extends StatelessWidget {
  final List<Inmueble> inmuebles;
  final bool loading;
  final Future<void> Function() onRefresh;
  final String token;

  const PaymentsScreen({
    super.key,
    required this.inmuebles,
    required this.loading,
    required this.onRefresh,
    required this.token,
  });

  double get totalDeuda => inmuebles.fold(
        0,
        (sum, i) =>
            sum +
            (double.tryParse((i.deudaActual ?? '').replaceAll(',', '.')) ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? theme.cardColor : const Color(0xfff0f1f6);
    final shadowColor = Colors.black.withOpacity(isDark ? 0.25 : 0.06);
    final textMuted = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Pagos'),
        centerTitle: true,
      ),
      body: loading
          ? _loadingSkeleton()
          : RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  _summaryCard(cardColor, shadowColor, textMuted),
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
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Sin inmuebles registrados.'),
                    )
                  else
                    Column(
                      children: _buildGroupedByCondominio(
                        context,
                        isDark,
                        cardColor,
                        shadowColor,
                        textMuted,
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _loadingSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      children: const [
        ShimmerSkeleton(height: 140, borderRadius: BorderRadius.all(Radius.circular(24))),
        SizedBox(height: 24),
        ShimmerSkeleton(height: 20, width: 160),
        SizedBox(height: 12),
        ShimmerSkeleton(height: 100, borderRadius: BorderRadius.all(Radius.circular(18))),
        SizedBox(height: 12),
        ShimmerSkeleton(height: 100, borderRadius: BorderRadius.all(Radius.circular(18))),
        SizedBox(height: 12),
        ShimmerSkeleton(height: 100, borderRadius: BorderRadius.all(Radius.circular(18))),
        SizedBox(height: 24),
        ShimmerSkeleton(height: 20, width: 180),
        SizedBox(height: 12),
        ShimmerSkeleton(height: 80, borderRadius: BorderRadius.all(Radius.circular(16))),
        SizedBox(height: 12),
        ShimmerSkeleton(height: 80, borderRadius: BorderRadius.all(Radius.circular(16))),
      ],
    );
  }

  Widget _summaryCard(Color cardColor, Color shadowColor, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
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
                  style: TextStyle(color: textMuted),
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

  List<Widget> _buildGroupedByCondominio(
    BuildContext context,
    bool isDark,
    Color cardColor,
    Color shadowColor,
    Color textMuted,
  ) {
    final Map<String, List<Inmueble>> grouped = {};
    for (final inmueble in inmuebles) {
      final label = _condominioLabel(inmueble);
      grouped.putIfAbsent(label, () => []).add(inmueble);
    }

    final sortedKeys = grouped.keys.toList()..sort();
    return sortedKeys
        .map(
          (key) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Text(
                  key,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StaggeredList(
                children: grouped[key]!
                    .map(
                      (i) => _inmuebleTile(
                        context,
                        isDark,
                        i,
                        cardColor,
                        shadowColor,
                        textMuted,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        )
        .toList();
  }

  Widget _inmuebleTile(
    BuildContext context,
    bool isDark,
    Inmueble inmueble,
    Color cardColor,
    Color shadowColor,
    Color textMuted,
  ) {
    final deuda =
        double.tryParse((inmueble.deudaActual ?? '').replaceAll(',', '.')) ?? 0;
    final sinDeuda = deuda <= 0;
    final derivedEstado = sinDeuda
        ? EstadoInmueble.alDia
        : (inmueble.estado == EstadoInmueble.alDia
            ? EstadoInmueble.moroso
            : inmueble.estado);
    final tileColor = sinDeuda
        ? (isDark ? const Color(0xff0f2d1a) : const Color(0xffecfdf3))
        : cardColor;
    final badgeColor =
        sinDeuda ? const Color(0xff16a34a) : const Color(0xff1d9bf0);
    final textColor =
        sinDeuda ? (isDark ? const Color(0xff6ee7a9) : const Color(0xff166534)) : null;
    final mutedLocal =
        sinDeuda ? (isDark ? const Color(0xff34d399) : const Color(0xff15803d)) : textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
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
              Icon(Icons.home_work_outlined, color: badgeColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inmueble.identificacion ?? 'Inmueble',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      inmueble.tipo ?? 'Propiedad',
                      style: TextStyle(color: mutedLocal),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _condominioLabel(inmueble),
                      style: TextStyle(
                        color: mutedLocal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _badgeEstado(derivedEstado),
            ],
          ),
          const SizedBox(height: 12),
          if (sinDeuda) ...[
            Row(
              children: const [
                Icon(Icons.emoji_events_outlined, color: Color(0xff16a34a)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sin deuda pendiente. ¡Gracias por estar al dia!',
                    style: TextStyle(
                      color: Color(0xff166534),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
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
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Proximo pago',
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
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openPaymentDetail(context, inmueble),
              icon: const Icon(Icons.history),
              label: const Text('Ver mas'),
            ),
          ),
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

  void _openPaymentDetail(BuildContext context, Inmueble inmueble) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentDetailScreen(
          inmueble: inmueble,
          token: token,
          totalDeuda: double.tryParse(
                (inmueble.deudaActual ?? '').replaceAll(',', '.'),
              ) ??
              0,
        ),
      ),
    );
  }

  String _condominioLabel(Inmueble inmueble) {
    final nombre = inmueble.nombreCondominio;
    if (nombre != null && nombre.trim().isNotEmpty) {
      return nombre.trim();
    }
    return 'Condominio #${inmueble.idCondominio}';
  }

  String _formatCurrency(double value) => '\$${value.toStringAsFixed(2)}';
}
