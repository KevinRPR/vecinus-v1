import 'dart:ui';

import 'package:flutter/material.dart';

import '../animations/shimmers.dart';
import '../models/inmueble.dart';
import '../preferences_controller.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import 'payment_detail_screen.dart';

enum _PaymentFilter { pending, paid, all }

class PaymentsScreen extends StatefulWidget {
  final List<Inmueble> inmuebles;
  final bool loading;
  final Future<void> Function() onRefresh;
  final String token;
  final DateTime? lastSync;

  const PaymentsScreen({
    super.key,
    required this.inmuebles,
    required this.loading,
    required this.onRefresh,
    required this.token,
    this.lastSync,
  });

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  _PaymentFilter _filter = _PaymentFilter.pending;

  double get _totalDeuda => widget.inmuebles.fold(
        0,
        (sum, i) => sum + _parseMonto(i.deudaActual),
      );

  double _parseMonto(String? raw) {
    if (raw == null) return 0;
    final cleaned = raw.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (cleaned.isEmpty) return 0;
    return double.tryParse(cleaned.replaceAll(',', '.')) ?? 0;
  }

  bool _sinDeuda(Inmueble inmueble) => _parseMonto(inmueble.deudaActual) <= 0;

  List<Inmueble> get _filteredInmuebles {
    final prefs = preferencesController.preferences.value;
    final favoriteId = prefs.inmueble.favoriteInmuebleId;
    switch (_filter) {
      case _PaymentFilter.paid:
        return _applyFavoriteSort(
          widget.inmuebles.where(_sinDeuda).toList(),
          favoriteId,
        );
      case _PaymentFilter.pending:
        return _applyFavoriteSort(
          widget.inmuebles.where((i) => !_sinDeuda(i)).toList(),
          favoriteId,
        );
      case _PaymentFilter.all:
        return _applyFavoriteSort(widget.inmuebles, favoriteId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: preferencesController.preferences,
      builder: (context, _, __) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final topPadding = MediaQuery.of(context).padding.top;
        final background = theme.scaffoldBackgroundColor;
        final cardColor = isDark ? const Color(0xff1F2A2A) : Colors.white;
        final borderColor = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06);
        final textMuted =
            isDark ? const Color(0xffA1A1AA) : const Color(0xff6B7280);

        return Scaffold(
          backgroundColor: background,
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: widget.onRefresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _PaymentsHeaderDelegate(
                        isDark: isDark,
                        topPadding: topPadding,
                        onOpenHelp: () => _openHelp(context),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: _summaryCard(
                          isDark: isDark,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          textMuted: textMuted,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _filterChips(isDark),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          'Detalle por inmueble',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: textMuted,
                          ),
                        ),
                      ),
                    ),
                    if (widget.loading && widget.inmuebles.isEmpty)
                      SliverToBoxAdapter(child: _loadingSkeleton())
                    else
                      SliverList(
                        delegate: SliverChildListDelegate(
                          _buildGroupedSections(
                            context,
                            _filteredInmuebles,
                            isDark: isDark,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            textMuted: textMuted,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 140)),
                  ],
                ),
              ),
              _buildPayNowBar(isDark),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard({
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color textMuted,
  }) {
    final totalCount = widget.inmuebles.length;
    final paidCount = widget.inmuebles.where(_sinDeuda).length;
    final progress = totalCount == 0 ? 0.0 : paidCount / totalCount;
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    final showProgress = !(widget.loading && totalCount == 0);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? cardColor : const Color(0xffE9ECEF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total adeudado',
                      style: TextStyle(
                        color: textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatCurrency(_totalDeuda),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xff0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.apartment,
                            size: 16, color: textMuted.withValues(alpha: 0.8)),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.inmuebles.length} inmuebles',
                          style: TextStyle(
                            color: textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 64,
                width: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: showProgress ? clampedProgress : null,
                      strokeWidth: 8,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.brandBlue600.withValues(alpha: 0.35),
                      ),
                      backgroundColor: AppColors.brandBlue600.withValues(alpha: 0.08),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: borderColor,
          ),
          const SizedBox(height: 10),
          Text(
            'Actualizado: ${widget.lastSync != null ? _formatLastSync(widget.lastSync!) : '--'}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('Pendiente', _PaymentFilter.pending, isDark),
          const SizedBox(width: 8),
          _filterChip('Pagado', _PaymentFilter.paid, isDark),
          const SizedBox(width: 8),
          _filterChip('Todos', _PaymentFilter.all, isDark),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _PaymentFilter value, bool isDark) {
    final selected = _filter == value;
    final background = selected
        ? AppColors.brandBlue600
        : (isDark ? const Color(0xff1F2A2A) : Colors.white);
    final border = selected
        ? Colors.transparent
        : (isDark ? Colors.white24 : const Color(0xffE5E7EB));
    final textColor = selected ? Colors.white : (isDark ? Colors.white70 : Colors.black54);

    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.brandBlue600.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedSections(
    BuildContext context,
    List<Inmueble> list, {
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color textMuted,
  }) {
    if (list.isEmpty) {
      return [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            'Sin inmuebles registrados.',
            style: TextStyle(color: textMuted, fontWeight: FontWeight.w600),
          ),
        ),
      ];
    }

    final grouped = <String, List<Inmueble>>{};
    for (final inmueble in list) {
      final label = _condominioLabel(inmueble);
      grouped.putIfAbsent(label, () => []).add(inmueble);
    }

    final keys = grouped.keys.toList()..sort();
    final widgets = <Widget>[];

    for (final key in keys) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            key.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: textMuted,
            ),
          ),
        ),
      );

      for (final inmueble in grouped[key]!) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _inmuebleCard(
              context,
              inmueble,
              isDark: isDark,
              cardColor: cardColor,
              borderColor: borderColor,
              textMuted: textMuted,
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _inmuebleCard(
    BuildContext context,
    Inmueble inmueble, {
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color textMuted,
  }) {
    final deuda = _parseMonto(inmueble.deudaActual);
    final sinDeuda = deuda <= 0;
    final status = _estadoLabel(inmueble, sinDeuda);
    final statusColor = _estadoColor(inmueble, sinDeuda);
    final mutedLocal = sinDeuda ? AppColors.brandBlue600 : textMuted;
    final background = sinDeuda
        ? AppColors.brandBlue600.withValues(alpha: isDark ? 0.15 : 0.08)
        : cardColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sinDeuda
                      ? Colors.white.withValues(alpha: isDark ? 0.06 : 0.8)
                      : (isDark ? const Color(0xff27313A) : const Color(0xffF3F4F6)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  inmueble.tipo?.toLowerCase().contains('estacion') == true
                      ? Icons.directions_car
                      : Icons.apartment,
                  color: sinDeuda ? AppColors.brandBlue600 : textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inmueble.identificacion ?? 'Inmueble',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: sinDeuda
                            ? AppColors.brandBlue600
                            : (isDark ? Colors.white : const Color(0xff0F172A)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      inmueble.tipo ?? 'Propiedad',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: mutedLocal,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (sinDeuda) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.emoji_events, color: AppColors.brandBlue600, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sin deuda pendiente. Gracias por estar al dia!',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandBlue600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deuda',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatCurrency(deuda),
                    style: TextStyle(
                      fontSize: sinDeuda ? 22 : 24,
                      fontWeight: FontWeight.w700,
                      color: sinDeuda
                          ? textMuted
                          : (isDark ? Colors.white : const Color(0xff0F172A)),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Proximo pago',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => _openPaymentDetail(context, inmueble),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xff007AFF),
                    ),
                    icon: const Icon(Icons.chevron_right, size: 16),
                    label: const Text(
                      'Ver detalle',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayNowBar(bool isDark) {
    final background = Theme.of(context)
        .scaffoldBackgroundColor
        .withValues(alpha: isDark ? 0.94 : 0.96);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final isLoading = widget.loading && widget.inmuebles.isEmpty;
    final hasPending = widget.inmuebles.any((i) => !_sinDeuda(i));
    final canPay = !isLoading && hasPending;
    final buttonLabel = isLoading
        ? 'Cargando...'
        : (hasPending ? 'Pagar ahora' : 'Sin deudas');
    final buttonIcon = isLoading
        ? Icons.hourglass_empty
        : (hasPending ? Icons.payments : Icons.check_circle_outline);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: background,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: ElevatedButton.icon(
          onPressed: canPay ? () => _handlePayNow(context) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandBlue600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          icon: Icon(buttonIcon),
          label: Text(
            buttonLabel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePayNow(BuildContext context) async {
    final security = preferencesController.preferences.value.security;
    final allowed = await SecurityService.requireAuthentication(
      context: context,
      useBiometrics: security.biometricForSensitive,
      usePin: security.pinForSensitive,
      reason: 'Confirma tu identidad para iniciar el pago.',
    );
    if (!context.mounted) return;
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo verificar tu identidad.')),
      );
      return;
    }
    final inmueble = _pickPendingInmueble();
    if (inmueble == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay deudas pendientes.')),
      );
      return;
    }
    _openPaymentDetail(context, inmueble);
  }

  Inmueble? _pickPendingInmueble() {
    final prefs = preferencesController.preferences.value;
    final favoriteId = prefs.inmueble.favoriteInmuebleId;
    if (favoriteId != null) {
      Inmueble? favorite;
      for (final item in widget.inmuebles) {
        if (item.idInmueble == favoriteId) {
          favorite = item;
          break;
        }
      }
      if (favorite != null && !_sinDeuda(favorite)) {
        return favorite;
      }
    }
    for (final inmueble in widget.inmuebles) {
      if (!_sinDeuda(inmueble)) return inmueble;
    }
    return null;
  }

  List<Inmueble> _applyFavoriteSort(List<Inmueble> items, String? favoriteId) {
    if (favoriteId == null || items.length < 2) return items;
    final index = items.indexWhere((item) => item.idInmueble == favoriteId);
    if (index <= 0) return items;
    final sorted = List<Inmueble>.from(items);
    final favorite = sorted.removeAt(index);
    sorted.insert(0, favorite);
    return sorted;
  }

  void _openHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final muted =
            Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
                AppColors.textMuted;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ayuda rapida',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Abre el detalle del inmueble para ver facturas y reportar tu pago.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _handlePayNow(context);
                    },
                    icon: const Icon(Icons.payments),
                    label: const Text('Ir a pagar'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _loadingSkeleton() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          ShimmerSkeleton(height: 140, borderRadius: BorderRadius.all(Radius.circular(24))),
          SizedBox(height: 16),
          ShimmerSkeleton(height: 40, borderRadius: BorderRadius.all(Radius.circular(20))),
          SizedBox(height: 16),
          ShimmerSkeleton(height: 180, borderRadius: BorderRadius.all(Radius.circular(20))),
          SizedBox(height: 12),
          ShimmerSkeleton(height: 120, borderRadius: BorderRadius.all(Radius.circular(20))),
        ],
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

  String _estadoLabel(Inmueble inmueble, bool sinDeuda) {
    if (sinDeuda) return 'Al dia';
    switch (inmueble.estado) {
      case EstadoInmueble.moroso:
        return 'Moroso';
      case EstadoInmueble.pendiente:
        return 'Pendiente';
      case EstadoInmueble.alDia:
      case EstadoInmueble.desconocido:
        return 'Pendiente';
    }
  }

  Color _estadoColor(Inmueble inmueble, bool sinDeuda) {
    if (sinDeuda) return const Color(0xff10B981);
    switch (inmueble.estado) {
      case EstadoInmueble.moroso:
        return const Color(0xffEF4444);
      case EstadoInmueble.pendiente:
        return const Color(0xffF59E0B);
      case EstadoInmueble.alDia:
      case EstadoInmueble.desconocido:
        return const Color(0xffF59E0B);
    }
  }

  Future<void> _openPaymentDetail(BuildContext context, Inmueble inmueble) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentDetailScreen(
          inmueble: inmueble,
          token: widget.token,
          totalDeuda: _parseMonto(inmueble.deudaActual),
        ),
      ),
    );
    if (!mounted) return;
    await widget.onRefresh();
  }

  String _formatCurrency(double value) => '\$${value.toStringAsFixed(2)}';

  String _formatLastSync(DateTime value) {
    final now = DateTime.now();
    final isToday =
        value.year == now.year && value.month == now.month && value.day == now.day;
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(value.hour)}:${two(value.minute)}';
    if (isToday) return 'Hoy $time';
    return '${two(value.day)}/${two(value.month)} $time';
  }
}

class _PaymentsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isDark;
  final double topPadding;
  final VoidCallback onOpenHelp;

  _PaymentsHeaderDelegate({
    required this.isDark,
    required this.topPadding,
    required this.onOpenHelp,
  });

  @override
  double get minExtent => topPadding + 64;

  @override
  double get maxExtent => topPadding + 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final background =
        theme.scaffoldBackgroundColor.withValues(alpha: 0.92);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.brandBlue600.withValues(alpha: 0.1);
    final contentHeight = maxExtent - topPadding - 24;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: background,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 12),
          child: SizedBox(
            height: contentHeight,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Pagos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xff0F172A),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onOpenHelp,
                  icon: const Icon(Icons.help_outline, color: AppColors.brandBlue600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PaymentsHeaderDelegate oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.onOpenHelp != onOpenHelp;
  }
}
