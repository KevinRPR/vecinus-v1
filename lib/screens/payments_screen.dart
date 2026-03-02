import 'dart:ui';

import 'package:flutter/material.dart';

import '../animations/shimmers.dart';
import '../models/inmueble.dart';
import '../preferences_controller.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import '../ui_system/components/app_empty_state.dart';
import '../ui_system/components/app_icon_button.dart';
import '../ui_system/components/app_status_chip.dart';
import '../ui_system/formatters/money.dart';
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
        final scheme = theme.colorScheme;
        final topPadding = MediaQuery.of(context).padding.top;
        final background = theme.scaffoldBackgroundColor;
        final cardColor = theme.cardColor;
        final surfaceAlt = scheme.surfaceContainerHighest;
        final borderColor = scheme.outline;
        final textMuted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
            (isDark ? AppColors.darkTextMuted : AppColors.textMuted);
        final sectionItems = _buildSectionItems(_filteredInmuebles);

        return Scaffold(
          backgroundColor: background,
          body: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PaymentsHeaderDelegate(
                    isDark: isDark,
                    topPadding: topPadding,
                    inmuebleCount: widget.inmuebles.length,
                    onOpenHelp: () => _openHelp(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _summaryCard(
                      isDark: isDark,
                      cardColor: cardColor,
                      surfaceAlt: surfaceAlt,
                      borderColor: borderColor,
                      textMuted: textMuted,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _filterChips(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
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
                else ...[
                  if (_filteredInmuebles.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildEmptyState(),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = sectionItems[index];
                          if (item.isHeader) {
                            return _buildSectionHeader(
                              item.header!,
                              textMuted,
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: _inmuebleCard(
                              context,
                              item.inmueble!,
                              isDark: isDark,
                              cardColor: cardColor,
                              borderColor: borderColor,
                              textMuted: textMuted,
                            ),
                          );
                        },
                        childCount: sectionItems.length,
                      ),
                    ),
                ],
                SliverToBoxAdapter(child: _buildPayNowBar()),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryCard({
    required bool isDark,
    required Color cardColor,
    required Color surfaceAlt,
    required Color borderColor,
    required Color textMuted,
  }) {
    final totalCount = widget.inmuebles.length;
    final paidCount = widget.inmuebles.where(_sinDeuda).length;
    final pendingCount = totalCount - paidCount;
    final allPaid = pendingCount == 0 && totalCount > 0;
    final statusLabel = totalCount == 0
        ? 'Sin inmuebles'
        : (allPaid ? 'Cuentas al dia' : '$pendingCount con deuda');
    final statusIcon = allPaid ? IconsRounded.check : IconsRounded.warning_rounded;
    final statusColor = allPaid ? AppColors.success : AppColors.warning;

    return Container(
      decoration: BoxDecoration(
        color: surfaceAlt,
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
                      'TOTAL ADEUDADO',
                      style: TextStyle(
                        color: textMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatCurrency(_totalDeuda),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(IconsRounded.apartment,
                            size: 16, color: textMuted.withValues(alpha: 0.8)),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
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
                child: Container(
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                  ),
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
            'ACTUALIZADO: ${widget.lastSync != null ? _formatLastSync(widget.lastSync!) : '--'}',
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

  Widget _filterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('Pendiente', _PaymentFilter.pending),
          const SizedBox(width: 8),
          _filterChip('Pagado', _PaymentFilter.paid),
          const SizedBox(width: 8),
          _filterChip('Todos', _PaymentFilter.all),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _PaymentFilter value) {
    final selected = _filter == value;
    final theme = Theme.of(context);
    final background = selected ? AppColors.brandBlue600 : theme.cardColor;
    final border =
        selected ? Colors.transparent : theme.colorScheme.outline;
    final textColor = selected
        ? Colors.white
        : theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: AppEmptyState(
        icon: IconsRounded.payments,
        title: 'Sin inmuebles registrados.',
        subtitle: 'Agrega un inmueble para ver tus pagos.',
      ),
    );
  }

  Widget _buildSectionHeader(String label, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
          color: textMuted,
        ),
      ),
    );
  }

  List<_SectionItem> _buildSectionItems(List<Inmueble> list) {
    if (list.isEmpty) return const [];

    final grouped = <String, List<Inmueble>>{};
    for (final inmueble in list) {
      final label = _condominioLabel(inmueble);
      grouped.putIfAbsent(label, () => []).add(inmueble);
    }

    final keys = grouped.keys.toList()..sort();
    final items = <_SectionItem>[];

    for (final key in keys) {
      items.add(_SectionItem.header(key));
      for (final inmueble in grouped[key]!) {
        items.add(_SectionItem.item(inmueble));
      }
    }

    return items;
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
    final status = _estadoStatus(inmueble, sinDeuda);
    final mutedLocal = sinDeuda ? AppColors.brandBlue600 : textMuted;
    final background = sinDeuda
        ? AppColors.brandBlue600.withValues(alpha: isDark ? 0.15 : 0.08)
        : cardColor;
    final surfaceAlt = Theme.of(context).colorScheme.surfaceContainerHighest;
    final iconBackground = sinDeuda
        ? Theme.of(context)
            .colorScheme
            .surface
            .withValues(alpha: isDark ? 0.25 : 0.85)
        : surfaceAlt;

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
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  inmueble.tipo?.toLowerCase().contains('estacion') == true
                      ? IconsRounded.directions_car
                      : IconsRounded.apartment,
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
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _inmuebleSubtitle(inmueble),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: mutedLocal,
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusChip(status: status, compact: true),
            ],
          ),
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
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _openPaymentDetail(context, inmueble),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    icon: const Icon(IconsRounded.chevron_right, size: 16),
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

  Widget _buildPayNowBar() {
    final theme = Theme.of(context);
    final isLoading = widget.loading && widget.inmuebles.isEmpty;
    final hasPending = widget.inmuebles.any((i) => !_sinDeuda(i));
    final canPay = !isLoading && hasPending;
    final buttonLabel =
        isLoading ? 'Cargando...' : (hasPending ? 'Pagar ahora' : 'Al dia');
    final buttonIcon = isLoading
        ? IconsRounded.hourglass_empty
        : (hasPending
            ? IconsRounded.payments
            : IconsRounded.check_circle_outline);
    final disabledBackground = theme.colorScheme.surfaceContainerHighest;
    const disabledForeground = AppColors.success;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: ElevatedButton.icon(
          onPressed: canPay ? () => _handlePayNow(context) : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? disabledBackground
                  : AppColors.brandBlue600,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? disabledForeground
                  : Colors.white,
            ),
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
                    icon: const Icon(IconsRounded.payments),
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
      padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
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
    final nombre = _cleanValue(inmueble.nombreCondominio);
    if (nombre != null) {
      return nombre;
    }
    return 'Condominio #${inmueble.idCondominio}';
  }

  AppStatus _estadoStatus(Inmueble inmueble, bool sinDeuda) {
    if (sinDeuda) return AppStatus.alDia;
    switch (inmueble.estado) {
      case EstadoInmueble.moroso:
        return AppStatus.atrasado;
      case EstadoInmueble.pendiente:
        return AppStatus.pendiente;
      case EstadoInmueble.alDia:
      case EstadoInmueble.desconocido:
        return AppStatus.pendiente;
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

  String _formatCurrency(double value) => formatMoney(value);

  String _formatLastSync(DateTime value) {
    final now = DateTime.now();
    final isToday =
        value.year == now.year && value.month == now.month && value.day == now.day;
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(value.hour)}:${two(value.minute)}';
    if (isToday) return 'Hoy $time';
    return '${two(value.day)}/${two(value.month)} $time';
  }

  String _inmuebleSubtitle(Inmueble inmueble) {
    final correlativo = _cleanValue(inmueble.correlativo);
    if (correlativo != null) {
      return 'Unidad $correlativo';
    }
    final manzana = _cleanValue(inmueble.manzana);
    if (manzana != null) {
      return 'Manzana $manzana';
    }
    final tipo = _cleanValue(inmueble.tipo);
    if (tipo != null) {
      return tipo;
    }
    return 'Propiedad';
  }

  String? _cleanValue(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final lowered = trimmed.toLowerCase();
    if (lowered == 'null' || lowered == 'undefined' || lowered == 'nan') {
      return null;
    }
    return trimmed;
  }
}

class _SectionItem {
  final String? header;
  final Inmueble? inmueble;

  const _SectionItem._({this.header, this.inmueble});

  const _SectionItem.header(String value) : this._(header: value);

  const _SectionItem.item(Inmueble value) : this._(inmueble: value);

  bool get isHeader => header != null;
}

class _PaymentsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isDark;
  final double topPadding;
  final int inmuebleCount;
  final VoidCallback onOpenHelp;

  _PaymentsHeaderDelegate({
    required this.isDark,
    required this.topPadding,
    required this.inmuebleCount,
    required this.onOpenHelp,
  });

  @override
  double get minExtent => topPadding + 80;

  @override
  double get maxExtent => topPadding + 80;

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
    final subtitle = inmuebleCount == 1
        ? '1 inmueble registrado'
        : '$inmuebleCount inmuebles registrados';
    final titleStyle = theme.appBarTheme.titleTextStyle ??
        theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: background,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 12),
          child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Pagos',
                        style: titleStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withValues(
                                alpha: 0.7,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                AppIconButton(
                  icon: IconsRounded.help_outline,
                  tooltip: 'Ayuda',
                  onPressed: onOpenHelp,
                ),
              ],
            ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PaymentsHeaderDelegate oldDelegate) {
    return oldDelegate.isDark != isDark ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.inmuebleCount != inmuebleCount ||
        oldDelegate.onOpenHelp != onOpenHelp;
  }
}
