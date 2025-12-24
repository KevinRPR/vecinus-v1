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
  final DateTime? lastSync;

  const DashboardScreen({
    super.key,
    required this.user,
    required this.inmuebles,
    required this.loading,
    required this.onRefresh,
    required this.onViewPayments,
    this.lastSync,
  });

  double get _totalDeuda => inmuebles.fold(
        0,
        (sum, item) =>
            sum +
            _parseMonto(item.deudaActual),
      );

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  double _parseMonto(String? raw) {
    if (raw == null) return 0;
    final cleaned = raw.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (cleaned.isEmpty) return 0;
    return double.tryParse(cleaned.replaceAll(',', '.')) ?? 0;
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
      final deudaA = _parseMonto(a.deudaActual);
      final deudaB = _parseMonto(b.deudaActual);
      return deudaB.compareTo(deudaA);
    });
    return list.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? theme.cardColor : const Color(0xffeef2f8);
    final shadowColor = Colors.black.withOpacity(isDark ? 0.2 : 0.05);
    final textMuted = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final onSurface = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Resumen'),
        centerTitle: true,
      ),
      body: loading && inmuebles.isEmpty
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
                    if (lastSync != null) ...[
                      const SizedBox(height: 8),
                      FadeSlideTransition(
                        beginOffset: const Offset(0, 0.02),
                        child: Row(
                          children: [
                            const Icon(Icons.refresh, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Actualizado: ${_formatLastSync(lastSync!)}',
                              style: TextStyle(color: textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FadeSlideTransition(
                      beginOffset: const Offset(0, 0.06),
                      child: _heroCard(theme),
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
          SizedBox(height: 24),
          ShimmerSkeleton(height: 120, borderRadius: BorderRadius.all(Radius.circular(18))),
          SizedBox(height: 16),
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

  String _formatLastSync(DateTime value) {
    final now = DateTime.now();
    final isToday =
        value.year == now.year && value.month == now.month && value.day == now.day;
    final two = (int n) => n.toString().padLeft(2, '0');
    final time = '${two(value.hour)}:${two(value.minute)}';
    if (isToday) return 'Hoy $time';
    return '${two(value.day)}/${two(value.month)} $time';
  }
}
