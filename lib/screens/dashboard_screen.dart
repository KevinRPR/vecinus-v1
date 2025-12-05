import 'package:flutter/material.dart';

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
    final cardColor = theme.cardColor;
    final shadowColor = theme.shadowColor ?? Colors.black.withOpacity(0.1);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Resumen'),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, ${user.displayName} 👋',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Aqui tienes una vista rapida de tus finanzas.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    _heroCard(theme),
                    const SizedBox(height: 20),
                    _statusRow(theme),
                    const SizedBox(height: 24),
                    _proximoPagoCard(cardColor, shadowColor),
                    const SizedBox(height: 24),
                    _destacadosSection(cardColor, shadowColor),
                  ],
                ),
              ),
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
              ? const [Color(0xff1d9bf0), Color(0xff123b7a)]
              : const [Color(0xff1d9bf0), Color(0xff1c6ae8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.15),
            blurRadius: 18,
            offset: const Offset(0, 10),
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
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xff1d9bf0),
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

  Widget _statusRow(ThemeData theme) {
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
              child: _StatusCard(info: item, theme: theme),
            ),
          )
          .toList(),
    );
  }

  Widget _proximoPagoCard(Color cardColor, Color shadowColor) {
    final inmueble = _proximoPago;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.2),
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
            const Text(
              'No hay pagos programados.',
              style: TextStyle(color: Colors.grey),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fecha: ${inmueble.proximaFechaPago}',
                        style: TextStyle(color: Colors.grey.shade600),
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

  Widget _destacadosSection(Color cardColor, Color shadowColor) {
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
        ..._inmueblesCruciales.map(
          (inmueble) => Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withOpacity(0.18),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
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
                Text(
                  _formatCurrency(
                    double.tryParse(
                          (inmueble.deudaActual ?? '').replaceAll(',', '.'),
                        ) ??
                        0,
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
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
  final ThemeData theme;

  const _StatusCard({required this.info, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                (theme.shadowColor ?? Colors.black.withOpacity(0.1))
                    .withOpacity(isDark ? 0.3 : 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
