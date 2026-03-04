import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/inmueble.dart';
import '../models/pago.dart';
import '../models/payment_report.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../ui_system/components/app_empty_state.dart';
import '../ui_system/components/app_icon_button.dart';
import '../ui_system/components/app_status_chip.dart';
import '../ui_system/formatters/money.dart';
import '../ui_system/formatters/safe_text.dart';
import 'inmueble_detail_screen.dart';
import 'payment_history_screen.dart';
import 'report_payment_screen.dart';

typedef ReportesLoader = Future<List<PaymentReport>> Function({
  required String token,
  String? idInmueble,
});

enum _PagoState { pending, overdue, paid }

class PaymentDetailScreen extends StatefulWidget {
  final Inmueble inmueble;
  final double totalDeuda;
  final String token;
  final ReportesLoader? reportesLoader;

  const PaymentDetailScreen({
    super.key,
    required this.inmueble,
    required this.totalDeuda,
    required this.token,
    this.reportesLoader,
  });

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  List<PaymentReport> _reportes = [];

  @override
  void initState() {
    super.initState();
    _loadReportes();
  }

  Future<void> _loadReportes() async {
    try {
      final loader = widget.reportesLoader ?? ApiService.getMisPagosReportados;
      final items = await loader(
        token: widget.token,
        idInmueble: widget.inmueble.idInmueble,
      );
      if (!mounted) return;
      setState(() {
        _reportes = items;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar los reportes: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final border = theme.colorScheme.outline;
    final shadow = isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.06);
    final muted =
        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ?? AppColors.textMuted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de pago'),
        actions: [
          AppIconButton(
            icon: IconsRounded.apartment,
            tooltip: 'Ver inmueble',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InmuebleDetailScreen(
                    inmueble: widget.inmueble,
                    token: widget.token,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              _subtitleText(),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadReportes,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _estadoCuentaCard(theme, cardColor, border, shadow, muted),
            const SizedBox(height: 20),
            _contribucionSection(context, muted),
            const SizedBox(height: 20),
            _reportesSection(context, muted),
          ],
        ),
      ),
    );
  }

  String _subtitleText() {
    final condominio = _condominioLabel();
    final unidad = safeTextOrEmpty(widget.inmueble.identificacion);
    if (unidad.isNotEmpty) {
      return '$condominio - $unidad';
    }
    return condominio;
  }

  Widget _contribucionSection(BuildContext context, Color muted) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final items = _pagosActivos;
    final total = items.fold<double>(0, (sum, p) => sum + _parseMonto(p.monto));

    if (items.isEmpty) {
      return const AppEmptyState(
        icon: IconsRounded.receipt_long,
        title: 'No hay deuda pendiente.',
        subtitle: 'Cuando exista deuda, aparecera aqui.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalle de la deuda',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _contribucionItem(context, items[i], muted),
                if (i != items.length - 1) const Divider(),
              ],
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total a contribuir',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    _formatCurrency(total),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contribucionItem(BuildContext context, Pago pago, Color muted) {
    final monto = _parseMonto(pago.monto);
    final fecha = _formatDateLabel(
      pago.fecha ?? pago.fechaEmision ?? pago.fechaVencimiento,
    );
    final description = safeText(pago.descripcion, fallback: 'Contribucion');
    final status = _statusForPago(pago);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: AppColors.brandBlue600.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            IconsRounded.receipt_long,
            color: AppColors.brandBlue600,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 4),
              Text(
                fecha,
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              AppStatusChip(status: status, compact: true),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatCurrency(monto),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _reportesSection(BuildContext context, Color muted) {
    final theme = Theme.of(context);
    final reportes = _reportesOrdenados;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Pagos reportados',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (reportes.isNotEmpty)
              TextButton(
                onPressed: () => _openHistorial(context),
                child: const Text('Ver historial'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (reportes.isEmpty)
          Text('No hay pagos reportados.', style: TextStyle(color: muted))
        else
          Column(
            children: [
              for (int i = 0; i < reportes.length && i < 3; i++) ...[
                _reporteItem(context, reportes[i], muted),
                if (i != 2 && i != reportes.length - 1)
                  const SizedBox(height: 10),
              ],
            ],
          ),
      ],
    );
  }

  Widget _reporteItem(
    BuildContext context,
    PaymentReport report,
    Color muted,
  ) {
    final theme = Theme.of(context);
    final monto = report.totalBase;
    final fecha = _formatReportDate(report);
    final status = _statusForReport(report);
    final observacion = safeTextOrEmpty(report.observacion);
    final motivo = safeTextOrEmpty(report.motivoRechazo);
    final hasEvidence = report.evidenciaUrl != null && report.evidenciaUrl!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: AppColors.brandBlue600.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              IconsRounded.receipt_long,
              color: AppColors.brandBlue600,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pago reportado',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  fecha,
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                AppStatusChip(status: status, compact: true),
                if (observacion.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    observacion,
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
                if (motivo.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    motivo,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (hasEvidence) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openEvidence(context, report),
                      icon: const Icon(IconsRounded.picture_as_pdf, size: 16),
                      label: const Text('Ver comprobante'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(44, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatCurrency(monto),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  void _openHistorial(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentHistoryScreen(
          inmueble: widget.inmueble,
        ),
      ),
    );
  }

  List<PaymentReport> get _reportesOrdenados {
    final list = List<PaymentReport>.from(_reportes);
    list.sort((a, b) => _parseReportDate(b).compareTo(_parseReportDate(a)));
    return list;
  }

  DateTime _parseReportDate(PaymentReport report) {
    if (report.createdAt != null) return report.createdAt!;
    return DateTime.tryParse(report.fechaPago) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatReportDate(PaymentReport report) {
    final raw = report.fechaPago.isNotEmpty ? report.fechaPago : null;
    return _formatDateLabel(raw);
  }

  AppStatus _statusForReport(PaymentReport report) {
    final estado = report.estado.toUpperCase();
    if (estado.contains('EN_PROCESO') || estado.contains('PROCESO')) {
      return AppStatus.enProceso;
    }
    if (estado.contains('APROB') || estado.contains('CONFIRM')) {
      return AppStatus.alDia;
    }
    if (estado.contains('RECH')) {
      return AppStatus.atrasado;
    }
    return AppStatus.pendiente;
  }

  Future<void> _openEvidence(BuildContext context, PaymentReport report) async {
    final url = report.evidenciaUrl;
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay comprobante disponible.')),
      );
      return;
    }
    final uri = Uri.parse(url.trim());
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
      const SnackBar(content: Text('No se pudo abrir el comprobante.')),
    );
  }

  String _formatDateLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'No disponible';
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return safeText(raw);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)}';
  }

  AppStatus _estadoCuentaStatus() {
    final deuda = widget.totalDeuda < 0 ? 0.0 : widget.totalDeuda;
    if (deuda <= 0) {
      return AppStatus.alDia;
    }
    final enProceso = _reportes.any((r) => r.estado == 'EN_PROCESO');
    if (enProceso) {
      return AppStatus.enProceso;
    }
    final vencido =
        _pagosActivos.any((p) => _classifyPago(p) == _PagoState.overdue);
    if (vencido) {
      return AppStatus.atrasado;
    }
    return AppStatus.pendiente;
  }

  Widget _estadoCuentaCard(
    ThemeData theme,
    Color cardColor,
    Color border,
    Color shadow,
    Color muted,
  ) {
    final double deuda = widget.totalDeuda < 0 ? 0.0 : widget.totalDeuda;
    final bool sinDeuda = deuda <= 0;
    final bool pagoCubre = _reportes.any(
      (r) => r.estado == 'EN_PROCESO' && (r.cubreTotalEstimado == true),
    );
    final status = _estadoCuentaStatus();
    final cobertura = _coberturaTexto();
    final nextDate = safeText(widget.inmueble.proximaFechaPago);
    final canReport = !sinDeuda;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: [
          if (shadow != Colors.transparent)
            BoxShadow(
              color: shadow,
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Estado de cuenta',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              AppStatusChip(status: status, compact: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            sinDeuda ? 'Sin deuda pendiente' : 'Saldo pendiente',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 6),
          Text(
            _formatCurrency(deuda),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                IconsRounded.calendar_month,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Proximo aporte: $nextDate',
                  style: TextStyle(color: muted),
                ),
              ),
            ],
          ),
          if (cobertura != null && cobertura.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (pagoCubre ? AppColors.success : AppColors.warning)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (pagoCubre ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                cobertura,
                style: TextStyle(
                  color: pagoCubre ? AppColors.success : AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canReport ? () => _reportarPago(context) : null,
              icon: const Icon(IconsRounded.upload_file),
              label: Text(canReport ? 'Reportar pago' : 'Sin deuda pendiente'),
            ),
          ),
        ],
      ),
    );
  }

  void _reportarPago(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportPaymentScreen(
          token: widget.token,
          inmueble: widget.inmueble,
        ),
      ),
    ).then((_) => _loadReportes());
  }

  String _condominioLabel() {
    final nombre = safeTextOrEmpty(widget.inmueble.nombreCondominio);
    if (nombre.isNotEmpty) {
      return nombre;
    }
    return 'Condominio #${widget.inmueble.idCondominio}';
  }

  String _formatCurrency(double value) => formatMoney(value);
  double _parseMonto(String? raw) =>
      double.tryParse((raw ?? '').replaceAll(',', '.')) ?? 0;

  List<Pago> get _pagosActivos =>
      widget.inmueble.pagos.where((p) => _classifyPago(p) != _PagoState.paid).toList();

  _PagoState _classifyPago(Pago pago) {
    final estado = (pago.estado ?? '').toLowerCase();
    if (estado.contains('pag')) return _PagoState.paid;

    DateTime? fechaVenc = DateTime.tryParse(
      pago.fechaVencimiento ?? pago.fecha ?? pago.fechaEmision ?? '',
    );
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
    if (estado.contains('pend')) return _PagoState.pending;
    return _PagoState.pending;
  }

  AppStatus _statusForPago(Pago pago) {
    final state = _classifyPago(pago);
    switch (state) {
      case _PagoState.overdue:
        return AppStatus.atrasado;
      case _PagoState.pending:
        return AppStatus.pendiente;
      case _PagoState.paid:
        return AppStatus.alDia;
    }
  }

  String? _coberturaTexto() {
    if (_reportes.isEmpty) return null;
    final PaymentReport enProceso = _reportes.firstWhere(
      (r) => r.estado == 'EN_PROCESO',
      orElse: () => _reportes.first,
    );
    final total = widget.totalDeuda;
    if (total <= 0) return null;
    final pagado = enProceso.pagosTotalBase ??
        enProceso.abonoTotalBase ??
        enProceso.totalBase;
    final ratio = total > 0 ? (pagado / total).clamp(0, 1) : 0.0;
    final porcentaje = (ratio * 100).toStringAsFixed(0);
    if (enProceso.cubreTotalEstimado == true || ratio >= 0.99) {
      return 'Pago cubre el 100% de la deuda y esta en proceso.';
    }
    return 'Pago parcial en proceso: cubre ~$porcentaje% de la deuda.';
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

}
