import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/inmueble.dart';
import '../models/pago.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../animations/transitions.dart';
import '../ui_system/perf/app_perf.dart';

enum _HistoryFilter { all, paid, pending, overdue }

class PaymentHistoryScreen extends StatefulWidget {
  final Inmueble inmueble;

  const PaymentHistoryScreen({
    super.key,
    required this.inmueble,
  });

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  List<Pago> get _pagosOrdenados {
    final list = List<Pago>.from(widget.inmueble.pagos);
    list.sort((a, b) {
      final aDate = _parsePagoDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = _parsePagoDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return list;
  }

  List<Pago> get _pagosFiltrados {
    final list = _pagosOrdenados;
    switch (_filter) {
      case _HistoryFilter.paid:
        return list.where((p) => _classifyPago(p) == _PagoState.paid).toList();
      case _HistoryFilter.pending:
        return list.where((p) => _classifyPago(p) == _PagoState.pending).toList();
      case _HistoryFilter.overdue:
        return list.where((p) => _classifyPago(p) == _PagoState.overdue).toList();
      case _HistoryFilter.all:
        return list;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final reduceEffects = AppPerf.reduceEffects(context);
    final shadowColor = Colors.black.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.3 : 0.08,
    );
    final muted =
        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65) ?? Colors.grey;
    final pagos = _pagosFiltrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de pagos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              _subtitleText(),
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          _buildFilters(theme),
          const SizedBox(height: 8),
          Expanded(
            child: pagos.isEmpty
                ? _emptyState(muted)
                : FadeSlideTransition(
                    beginOffset: const Offset(0, 0.02),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: pagos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) => _pagoTile(
                        context,
                        pagos[index],
                        cardColor,
                        shadowColor,
                        muted,
                        reduceEffects,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _filterChip('Todos', _HistoryFilter.all, theme),
          const SizedBox(width: 8),
          _filterChip('Pagados', _HistoryFilter.paid, theme),
          const SizedBox(width: 8),
          _filterChip('Pendientes', _HistoryFilter.pending, theme),
          const SizedBox(width: 8),
          _filterChip('Atrasados', _HistoryFilter.overdue, theme),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _HistoryFilter value, ThemeData theme) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      showCheckmark: false,
      selectedColor: AppColors.brandBlue600.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: selected ? AppColors.brandBlue600 : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected
            ? AppColors.brandBlue600.withValues(alpha: 0.4)
            : theme.colorScheme.outline,
      ),
    );
  }

  Widget _emptyState(Color muted) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'No hay pagos registrados para este inmueble.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted),
        ),
      ),
    );
  }

  Widget _pagoTile(
    BuildContext context,
    Pago pago,
    Color cardColor,
    Color shadowColor,
    Color muted,
    bool reduceEffects,
  ) {
    final status = _classifyPago(pago);
    final statusLabel = _statusLabel(status);
    final statusColor = _statusColor(status);
    final monto = _parseMonto(pago.monto);
    final fecha = pago.fecha ?? pago.fechaEmision ?? pago.fechaVencimiento ?? '--';
    final docUrl = _pickDocumentUrl(pago);
    final hasDoc = docUrl != null && docUrl.isNotEmpty;

    return InkWell(
      onTap: hasDoc ? () => _openDocument(context, pago) : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: reduceEffects
              ? const []
              : [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                status == _PagoState.paid
                    ? IconsRounded.check_circle
                    : IconsRounded.receipt_long,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pago.descripcion ?? 'Pago ${pago.id}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(fecha, style: TextStyle(color: muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  _statusPill(label: statusLabel, color: statusColor),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(monto),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (hasDoc)
                  TextButton.icon(
                    onPressed: () => _openDocument(context, pago),
                    icon: const Icon(IconsRounded.picture_as_pdf, size: 16),
                    label: const Text('Documento'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(44, 36),
                    ),
                  )
                else
                  Text(
                    'Documento no disponible',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  String _subtitleText() {
    final condominio = widget.inmueble.nombreCondominio?.trim();
    final unidad = widget.inmueble.identificacion?.trim();
    final label = condominio != null && condominio.isNotEmpty
        ? condominio
        : 'Condominio #${widget.inmueble.idCondominio}';
    if (unidad != null && unidad.isNotEmpty) {
      return '$label - $unidad';
    }
    return label;
  }

  String _formatCurrency(double value) => '\$${value.toStringAsFixed(2)}';

  double _parseMonto(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  DateTime? _parsePagoDate(Pago pago) {
    return DateTime.tryParse(
      pago.fecha ?? pago.fechaEmision ?? pago.fechaVencimiento ?? '',
    );
  }

  _PagoState _classifyPago(Pago pago) {
    final estado = (pago.estado ?? '').toLowerCase();
    if (estado.contains('pag')) return _PagoState.paid;

    final fechaVenc = _parsePagoDate(pago);
    if (fechaVenc != null) {
      final due = DateTime(fechaVenc.year, fechaVenc.month, fechaVenc.day);
      if (due.isBefore(_today())) {
        return _PagoState.overdue;
      }
      return _PagoState.pending;
    }

    if (estado.contains('venc') || estado.contains('atras') || estado.contains('moro')) {
      return _PagoState.overdue;
    }
    return _PagoState.pending;
  }

  String _statusLabel(_PagoState state) {
    switch (state) {
      case _PagoState.overdue:
        return 'Atrasado';
      case _PagoState.pending:
        return 'Pendiente';
      case _PagoState.paid:
        return 'Pagada';
    }
  }

  Color _statusColor(_PagoState state) {
    switch (state) {
      case _PagoState.overdue:
        return AppColors.error;
      case _PagoState.pending:
        return AppColors.warning;
      case _PagoState.paid:
        return AppColors.success;
    }
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _openDocument(BuildContext context, Pago pago) async {
    final url = _pickDocumentUrl(pago);
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay documento disponible para este pago.')),
      );
      return;
    }
    final uri = Uri.parse(url);
    final openedExternal = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (openedExternal) return;

    final openedInApp = await launchUrl(
      uri,
      mode: LaunchMode.inAppBrowserView,
    );
    if (openedInApp) return;

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el documento.')),
    );
  }

  String? _pickDocumentUrl(Pago pago) {
    if (pago.documentoUrl != null && pago.documentoUrl!.trim().isNotEmpty) {
      return pago.documentoUrl!.trim();
    }
    if (pago.reciboUrl != null && pago.reciboUrl!.trim().isNotEmpty) {
      return pago.reciboUrl!.trim();
    }
    if (pago.notificacionUrl != null &&
        pago.notificacionUrl!.trim().isNotEmpty) {
      return pago.notificacionUrl!.trim();
    }
    if (pago.token != null && pago.token!.trim().isNotEmpty) {
      final base = ApiService.baseRoot.endsWith('/')
          ? ApiService.baseRoot
          : '${ApiService.baseRoot}/';
      return '${base}sys/generar_notificacion.php?token=${pago.token}';
    }
    if (pago.id.isNotEmpty) {
      final base = ApiService.baseRoot.endsWith('/')
          ? ApiService.baseRoot
          : '${ApiService.baseRoot}/';
      return '${base}sys/generar_notificacion.php?id_notificacion=${pago.id}';
    }
    return null;
  }
}

enum _PagoState { pending, overdue, paid }
