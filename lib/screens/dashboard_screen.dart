import 'package:flutter/material.dart';

import '../animations/shimmers.dart';
import '../animations/stagger_list.dart';
import '../animations/tap_effect.dart';
import '../animations/transitions.dart';
import '../models/inmueble.dart';
import '../models/user.dart';

class DashboardScreen extends StatelessWidget {
  final User user;
  final List<Inmueble> inmuebles;
  final bool loading;
  final Future<void> Function() onRefresh;
  final VoidCallback onViewPayments;

  const DashboardScreen({
    super.key,
    required this.user,
    required this.inmuebles,
    required this.loading,
    required this.onRefresh,
    required this.onViewPayments,
  });

  double get _totalDeuda => inmuebles.fold(
        0,
        (sum, item) =>
            sum +
            (double.tryParse(
                  (item.deudaActual ?? '').replaceAll(',', '.'),
                ) ??
                0),
      );

  int _countByStatus(EstadoInmueble status) =>
      inmuebles.where((i) => i.estado == status).length;

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Inmueble? get _proximoPago {
    final pagos = inmuebles
        .where((i) => _parseDate(i.proximaFechaPago) != null)
        .toList();
    pagos.sort((a, b) {
      final dateA = _parseDate(a.proximaFechaPago)!;
      final dateB = _parseDate(b.proximaFechaPago)!;
      return dateA.compareTo(dateB);
    });
    return pagos.isEmpty ? null : pagos.first;
  }

  List<Inmueble> get _inmueblesCruciales {
    final list = List<Inmueble>.from(inmuebles);
    list.sort((a, b) {
      final deudaA =
          double.tryParse((a.deudaActual ?? '').replaceAll(',', '.')) ?? 0;
      final deudaB =
          double.tryParse((b.deudaActual ?? '').replaceAll(',', '.')) ?? 0;
      return deudaB.compareTo(deudaA);
    });
    return list.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? theme.cardColor : const Color(0xfff0f1f6);
    final shadowColor = Colors.black.withOpacity(isDark ? 0.25 : 0.06);
    final textMuted = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Resumen'),
        centerTitle: true,
      ),
      body: loading
          ? _loadingSkeleton(cardColor)
          : RefreshIndicator(
              onRefresh: onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeSlideTransition(
                      child: Text(
                        'Hola, ${user.displayName}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FadeSlideTransition(
                      beginOffset: const Offset(0, 0.03),
                      child: Text(
                        'Aqui tienes una vista rapida de tus finanzas.',
                        style: TextStyle(color: textMuted),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeSlideTransition(
                      beginOffset: const Offset(0, 0.06),
                      child: _heroCard(theme),
                    ),
                    const SizedBox(height: 20),
                    FadeSlideTransition(
                      beginOffset: const Offset(0, 0.04),
                      child: _statusRow(cardColor, shadowColor, textMuted),
                    ),
                    const SizedBox(height: 24),
                    FadeSlideTransition(
                      beginOffset: const Offset(0, 0.04),
                      child: _proximoPagoCard(
                          cardColor, shadowColor, textMuted, onSurface),
                    ),
                    const SizedBox(height: 24),
                    FadeSlideTransition(
                      beginOffset: const Offset(0, 0.04),
                      child: _destacadosSection(
                          cardColor, shadowColor, textMuted, onSurface),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _loadingSkeleton(Color cardColor) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerSkeleton(height: 22, width: 200),
          SizedBox(height: 12),
          ShimmerSkeleton(height: 16, width: 220),
          SizedBox(height: 24),
          ShimmerSkeleton(height: 180, borderRadius: BorderRadius.all(Radius.circular(24))),
          SizedBox(height: 20),
          ShimmerSkeleton(height: 80, borderRadius: BorderRadius.all(Radius.circular(18))),
          SizedBox(height: 12),
          ShimmerSkeleton(height: 80, borderRadius: BorderRadius.all(Radius.circular(18))),
          SizedBox(height: 12),
          ShimmerSkeleton(height: 80, borderRadius: BorderRadius.all(Radius.circular(18))),
          SizedBox(height: 24),
          ShimmerSkeleton(height: 120, borderRadius: BorderRadius.all(Radius.circular(18))),
          SizedBox(height: 12),
          ShimmerSkeleton(height: 120, borderRadius: BorderRadius.all(Radius.circular(18))),
        ],
      ),
    );
  }

  Widget _heroCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xff1d9bf0), Color(0xff0f6fcf)]
              : const [Color(0xff1d9bf0), Color(0xff4ba3ff)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deuda total',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(_totalDeuda),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TapEffect(
                  onTap: onViewPayments,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.12)
                          : Colors.white,
                      foregroundColor:
                          isDark ? Colors.white : const Color(0xff1d9bf0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: onViewPayments,
                    icon: const Icon(Icons.account_balance_wallet_outlined),
                    label: const Text('Ir a pagos'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.autorenew, color: Colors.white),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Actualiza para sincronizar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusRow(Color cardColor, Color shadowColor, Color textMuted) {
    final cards = [
      _StatusInfo(
        label: 'Al dia',
        value: _countByStatus(EstadoInmueble.alDia),
        color: const Color(0xff16a34a),
        icon: Icons.task_alt,
      ),
      _StatusInfo(
        label: 'Pendiente',
        value: _countByStatus(EstadoInmueble.pendiente),
        color: const Color(0xfff97316),
        icon: Icons.access_time,
      ),
      _StatusInfo(
        label: 'Moroso',
        value: _countByStatus(EstadoInmueble.moroso),
        color: const Color(0xffef4444),
        icon: Icons.warning_amber_rounded,
      ),
    ];

    return Row(
      children: cards
          .map(
            (item) => Expanded(
              child: FadeSlideTransition(
                beginOffset: const Offset(0, 0.05),
                child: _StatusCard(
                  info: item,
                  cardColor: cardColor,
                  shadowColor: shadowColor,
                  textMuted: textMuted,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _proximoPagoCard(
    Color cardColor,
    Color shadowColor,
    Color textMuted,
    Color onSurface,
  ) {
    final inmueble = _proximoPago;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Proximo pago',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (inmueble == null)
            Text(
              'No hay pagos programados.',
              style: TextStyle(color: textMuted),
            )
          else
            Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xffe5f2ff),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.event_available,
                      color: Color(0xff1d9bf0)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inmueble.identificacion ?? 'Inmueble',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fecha: ${inmueble.proximaFechaPago}',
                        style: TextStyle(color: textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _destacadosSection(
    Color cardColor,
    Color shadowColor,
    Color textMuted,
    Color onSurface,
  ) {
    if (_inmueblesCruciales.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Inmuebles con mayor deuda',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        StaggeredList(
          children: _inmueblesCruciales
              .map(
                (inmueble) => Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xfffef3c7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.home_work_outlined,
                            color: Color(0xfff59e0b)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      Text(
                        inmueble.identificacion ?? 'Inmueble',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                         color: onSurface,
                       ),
                     ),
                     const SizedBox(height: 4),
                     Text(
                       inmueble.tipo ?? 'Propiedad',
                       style: TextStyle(color: textMuted),
                     ),
                   ],
                 ),
               ),
                Text(
                  _formatCurrency(
                    double.tryParse(
                          (inmueble.deudaActual ?? '').replaceAll(',', '.'),
                        ) ??
                        0,
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }
}

class _StatusInfo {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatusInfo({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

class _StatusCard extends StatelessWidget {
  final _StatusInfo info;
  final Color cardColor;
  final Color shadowColor;
  final Color textMuted;

  const _StatusCard({
    required this.info,
    required this.cardColor,
    required this.shadowColor,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
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
        children: [
          Icon(info.icon, color: info.color),
          const SizedBox(height: 8),
          Text(
            '${info.value}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            info.label,
            style: TextStyle(
              fontSize: 13,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
