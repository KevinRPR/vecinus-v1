import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/inmueble.dart';
import '../models/pago.dart';
import '../models/payment_report.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'inmueble_detail_screen.dart';
import 'payment_history_screen.dart';
import 'report_payment_screen.dart';

typedef ReportesLoader = Future<List<PaymentReport>> Function({
  required String token,
  String? idInmueble,
});

enum _PagoState { pending, overdue, paid }

class _PagoBadge {
  final String label;
  final Color color;

  const _PagoBadge({required this.label, required this.color});
}

class _StatusInfo {
  final String label;
  final Color color;

  const _StatusInfo({required this.label, required this.color});
}

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
  bool _loadingReportes = false;
  String? _reportesError;

  @override
  void initState() {
    super.initState();
    _loadReportes();
  }

  Future<void> _loadReportes() async {
    setState(() {
      _loadingReportes = true;
      _reportesError = null;
    });
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
      setState(() {
        _reportesError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loadingReportes = false);
      }
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
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Ver inmueble',
            icon: const Icon(Icons.apartment_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InmuebleDetailScreen(
                    inmueble: widget.inmueble,
                  ),
                ),
              );
            },
          ),
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
            const SizedBox(height: 24),
            _sectionCard(
              title: 'Desglose de la deuda',
              icon: Icons.receipt_long,
              child: _pagosActivos.isEmpty
                  ? _emptyStateCard(
                      context,
                      icon: Icons.receipt_long_outlined,
                      title: 'No hay deuda pendiente.',
                      subtitle: 'Cuando exista deuda, aparecera aqui.',
                    )
                  : _facturaDeudaBody(context, muted),
            ),
            const SizedBox(height: 24),
            _sectionCard(
              title: 'Pagos reportados',
              icon: Icons.upload_file_outlined,
              action: _historyActionButton(context),
              child: _reportedPaymentsSection(cardColor, shadow, muted),
            ),
          ],
        ),
      ),
    );
  }

  void _openHistorialPagos(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentHistoryScreen(
          inmueble: widget.inmueble,
        ),
      ),
    );
  }

  String _subtitleText() {
    final condominio = _condominioLabel();
    final unidad = widget.inmueble.identificacion?.trim();
    if (unidad != null && unidad.isNotEmpty) {
      return '$condominio - $unidad';
    }
    return condominio;
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.brandBlue600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _historyActionButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _openHistorialPagos(context),
      icon: const Icon(Icons.history, size: 18),
      label: const Text('Ver historial'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
        foregroundColor: AppColors.brandBlue600,
        side: const BorderSide(color: AppColors.brandBlue600),
      ),
    );
  }

  Widget _emptyStateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted =
        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ?? AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 12),
            action,
          ],
        ],
      ),
    );
  }

  _StatusInfo _estadoCuentaStatus() {
    final deuda = widget.totalDeuda < 0 ? 0.0 : widget.totalDeuda;
    if (deuda <= 0) {
      return const _StatusInfo(label: 'Sin deuda', color: AppColors.success);
    }
    final enProceso = _reportes.any((r) => r.estado == 'EN_PROCESO');
    if (enProceso) {
      return const _StatusInfo(label: 'En proceso', color: AppColors.info);
    }
    final vencido =
        _pagosActivos.any((p) => _classifyPago(p) == _PagoState.overdue);
    if (vencido) {
      return const _StatusInfo(label: 'Atrasado', color: AppColors.error);
    }
    return const _StatusInfo(label: 'Pendiente de pago', color: AppColors.warning);
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
              _statusPill(label: status.label, color: status.color),
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
                Icons.event_available_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Proximo pago: ${widget.inmueble.proximaFechaPago?.isNotEmpty == true ? widget.inmueble.proximaFechaPago : '--'}',
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
            child: sinDeuda
                ? OutlinedButton.icon(
                    onPressed: () => _openHistorialPagos(context),
                    icon: const Icon(Icons.history),
                    label: const Text('Ver historial de pagos'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: AppColors.brandBlue600,
                      side: const BorderSide(color: AppColors.brandBlue600),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () => _reportarPago(context),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Reportar pago'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _reportedPaymentsSection(Color cardColor, Color shadow, Color muted) {
    if (_loadingReportes) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_reportesError != null) {
      return _emptyStateCard(
        context,
        icon: Icons.cloud_off_outlined,
        title: 'No se pudieron cargar los reportes.',
        subtitle: 'Revisa tu conexion e intenta de nuevo.',
        action: OutlinedButton(
          onPressed: _loadReportes,
          child: const Text('Reintentar'),
        ),
      );
    }
    if (_reportes.isEmpty) {
      return _emptyStateCard(
        context,
        icon: Icons.inbox_outlined,
        title: 'No hay pagos reportados.',
        subtitle: 'Cuando reportes un pago aparecera aqui.',
      );
    }

    return Column(
      children: _reportes.map((r) {
        final status = r.estado.toUpperCase();
        final chip = _statusChip(status);
        final created =
            r.createdAt?.toIso8601String().split('T').first ?? '--';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            boxShadow: [
              if (shadow != Colors.transparent)
                BoxShadow(
                  color: shadow,
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    color: AppColors.brandBlue600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Reporte ${r.id}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  chip,
                ],
              ),
              const SizedBox(height: 6),
                Text('Fecha pago: ${r.fechaPago}', style: TextStyle(color: muted)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child:
                        Text('Monto base', style: TextStyle(color: muted)),
                  ),
                  Text(
                    _formatCurrency(r.totalBase),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              if (r.observacion?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text('Obs: ${r.observacion}', style: TextStyle(color: muted)),
              ],
              if (status == 'RECHAZADO' && r.motivoRechazo != null && r.motivoRechazo!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Motivo rechazo: ${r.motivoRechazo}',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (r.cubreTotalEstimado != null) ...[
                const SizedBox(height: 4),
                Text(
                  r.cubreTotalEstimado! ? 'Cubre la deuda completa (en proceso)' : 'Pago parcial en proceso',
                  style: TextStyle(
                    color: r.cubreTotalEstimado!
                        ? AppColors.success
                        : AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (r.evidenciaUrl != null && r.evidenciaUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(r.evidenciaUrl!);
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text('Ver comprobante'),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Enviado: $created',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _statusChip(String estado) {
    Color color;
    String label;
    switch (estado) {
      case 'APROBADO':
        color = AppColors.success;
        label = 'Aprobado';
        break;
      case 'RECHAZADO':
        color = AppColors.error;
        label = 'Rechazado';
        break;
      default:
        color = AppColors.info;
        label = 'En proceso';
    }
    return _statusPill(label: label, color: color);
  }

  Widget _statusPill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _facturaDeudaBody(
    BuildContext context,
    Color muted,
  ) {
    final items = _pagosActivos;
    final total = items.fold<double>(0, (sum, p) => sum + _parseMonto(p.monto));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(items.length, (index) {
          final pago = items[index];
          final monto = _parseMonto(pago.monto);
          final badge = _PagoBadge(
            label: _statusLabel(pago),
            color: _statusColor(pago),
          );
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pago.descripcion ?? 'Pago',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pago.fecha ?? pago.fechaEmision ?? pago.fechaVencimiento ?? '--',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        _statusPill(label: badge.label, color: badge.color),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatCurrency(monto),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final hasDocument =
                              _pickDocumentUrl(pago)?.trim().isNotEmpty == true;
                          return TextButton.icon(
                            onPressed:
                                hasDocument ? () => _openDocument(context, pago) : null,
                            icon: Icon(
                              hasDocument
                                  ? Icons.picture_as_pdf
                                  : Icons.remove_circle_outline,
                              size: 16,
                            ),
                            label: Text(hasDocument ? 'Documento' : 'No disponible'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              if (index < items.length - 1) const Divider(),
            ],
          );
        }),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              _formatCurrency(total),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
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
    final nombre = widget.inmueble.nombreCondominio;
    if (nombre != null && nombre.trim().isNotEmpty) {
      return nombre.trim();
    }
    return 'Condominio #${widget.inmueble.idCondominio}';
  }

  String _formatCurrency(double value) => '\$${value.toStringAsFixed(2)}';
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

  String _statusLabel(Pago pago) {
    final state = _classifyPago(pago);
    switch (state) {
      case _PagoState.overdue:
        return 'Atrasado';
      case _PagoState.pending:
        return 'Pendiente';
      case _PagoState.paid:
        return 'Pagada';
    }
  }

  Color _statusColor(Pago pago) {
    final state = _classifyPago(pago);
    switch (state) {
      case _PagoState.overdue:
        return AppColors.error;
      case _PagoState.pending:
        return AppColors.warning;
      case _PagoState.paid:
        return AppColors.success;
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
