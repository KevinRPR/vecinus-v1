import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/inmueble.dart';
import '../models/pago.dart';
import '../models/payment_report.dart';
import '../services/api_service.dart';
import 'report_payment_screen.dart';

enum _PagoState { pending, overdue, paid }

class _PagoBadge {
  final String label;
  final Color color;

  const _PagoBadge({required this.label, required this.color});
}

class PaymentDetailScreen extends StatefulWidget {
  final Inmueble inmueble;
  final double totalDeuda;
  final String token;

  const PaymentDetailScreen({
    super.key,
    required this.inmueble,
    required this.totalDeuda,
    required this.token,
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
      final items = await ApiService.getMisPagosReportados(
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
    final cardColor = theme.cardColor;
    final shadow =
        Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.08);
    final muted =
        theme.textTheme.bodyMedium?.color?.withOpacity(0.65) ?? Colors.grey;

    final cobertura = _coberturaTexto();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de pago'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historial pagado',
            onPressed: _showHistorialPagado,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReportes,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _headerCard(cardColor, shadow, muted, theme),
            const SizedBox(height: 20),
            _deudaCard(cardColor, shadow, muted, cobertura),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _reportarPago(context),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Pagar'),
            ),
            const SizedBox(height: 24),
            Text(
              'Desglose de la deuda',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_pagosActivos.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: shadow,
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  'No hay deudas activas o vencidas para este inmueble.',
                  style: TextStyle(color: muted),
                ),
              )
            else
              _facturaDeudaCard(context, cardColor, shadow, muted),
            const SizedBox(height: 20),
            Text(
              'Historial de pagadas',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_pagosPagados.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: shadow,
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  'Aun no hay pagos registrados como pagados.',
                  style: TextStyle(color: muted),
                ),
              )
            else
              Column(
                children: _pagosPagados
                    .map((pago) => _pagoTile(
                          context,
                          pago,
                          cardColor,
                          shadow,
                          muted,
                          const _PagoBadge(
                            label: 'Pagada',
                            color: Color(0xff16a34a),
                          ),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 24),
            Text(
              'Pagos reportados',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _reportedPaymentsSection(cardColor, shadow, muted),
          ],
        ),
      ),
    );
  }

  void _showHistorialPagado() {
    if (_pagosPagados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay historial pagado.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _pagosPagados.length,
          itemBuilder: (_, i) {
            final pago = _pagosPagados[i];
            return ListTile(
              leading: const Icon(Icons.check_circle, color: Color(0xff16a34a)),
              title: Text(pago.descripcion ?? 'Pago'),
              subtitle: Text(pago.fecha ?? pago.fechaEmision ?? '--'),
              trailing: Text('\$${pago.monto ?? '--'}'),
            );
          },
        );
      },
    );
  }

  Widget _reportedPaymentsSection(Color cardColor, Color shadow, Color muted) {
    if (_loadingReportes) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reportesError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_reportesError!, style: TextStyle(color: muted)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _loadReportes,
            child: const Text('Reintentar'),
          ),
        ],
      );
    }
    if (_reportes.isEmpty) {
      return Text('No hay pagos reportados para este inmueble.', style: TextStyle(color: muted));
    }

    return Column(
      children: _reportes.map((r) {
        final status = r.estado.toUpperCase();
        final chip = _statusChip(status);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
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
                  const Icon(Icons.receipt_long, color: Color(0xff1d9bf0)),
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
              Text('Monto base: \$${r.totalBase.toStringAsFixed(2)}', style: TextStyle(color: muted)),
              if (r.observacion?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text('Obs: ${r.observacion}', style: TextStyle(color: muted)),
              ],
              if (status == 'RECHAZADO' && r.motivoRechazo != null && r.motivoRechazo!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Motivo rechazo: ${r.motivoRechazo}',
                  style: const TextStyle(color: Color(0xffb91c1c), fontWeight: FontWeight.w600),
                ),
              ],
              if (r.cubreTotalEstimado != null) ...[
                const SizedBox(height: 4),
                Text(
                  r.cubreTotalEstimado! ? 'Cubre la deuda completa (en proceso)' : 'Pago parcial en proceso',
                  style: TextStyle(
                    color: r.cubreTotalEstimado! ? const Color(0xff15803d) : const Color(0xffb45309),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (r.evidenciaUrl != null && r.evidenciaUrl!.isNotEmpty) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse(r.evidenciaUrl!);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: Text(
                    'Ver comprobante',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Enviado: ${r.createdAt?.toIso8601String() ?? '--'}',
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
        color = const Color(0xff16a34a);
        label = 'Aprobado';
        break;
      case 'RECHAZADO':
        color = const Color(0xffb91c1c);
        label = 'Rechazado';
        break;
      default:
        color = const Color(0xff2563eb);
        label = 'En proceso';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _headerCard(
    Color cardColor,
    Color shadow,
    Color muted,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadow,
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
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: const Color(0xffe8f3ff),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.apartment_rounded, color: Color(0xff1d9bf0)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _condominioLabel(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.inmueble.identificacion ?? 'Inmueble',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.inmueble.tipo ?? 'Propiedad',
            style: TextStyle(color: muted),
          ),
        ],
      ),
    );
  }

  Widget _deudaCard(Color cardColor, Color shadow, Color muted, String? cobertura) {
    final double deuda = widget.totalDeuda < 0 ? 0.0 : widget.totalDeuda;
    final bool sinDeuda = deuda <= 0;
    final bool pagoCubre = _reportes.any(
      (r) => r.estado == 'EN_PROCESO' && (r.cubreTotalEstimado == true),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadow,
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sinDeuda
                ? 'Sin deuda pendiente'
                : pagoCubre
                    ? 'Pago en proceso: marcado como pendiente'
                    : 'Saldo pendiente por pagar para estar solvente',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(deuda),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (cobertura != null && cobertura.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              cobertura,
              style: TextStyle(
                color: pagoCubre ? const Color(0xff15803d) : const Color(0xffb45309),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.event_available, color: Color(0xff1d9bf0)),
              const SizedBox(width: 8),
              Text(
                'Proximo pago: ${widget.inmueble.proximaFechaPago?.isNotEmpty == true ? widget.inmueble.proximaFechaPago : '--'}',
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _facturaDeudaCard(
    BuildContext context,
    Color cardColor,
    Color shadow,
    Color muted,
  ) {
    final items = _pagosActivos;
    final total = items.fold<double>(0, (sum, p) => sum + _parseMonto(p.monto));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
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
            children: const [
              Icon(Icons.receipt_long, color: Color(0xff0ea5e9)),
              SizedBox(width: 8),
              Text(
                'Factura de deuda',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: badge.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badge.label,
                              style: TextStyle(
                                color: badge.color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(monto),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextButton.icon(
                          onPressed: () => _openDocument(context, pago),
                          icon: const Icon(Icons.picture_as_pdf, size: 16),
                          label: const Text('Documento'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
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
      ),
    );
  }

  Widget _pagoTile(
    BuildContext context,
    Pago pago,
    Color cardColor,
    Color shadow,
    Color muted,
    _PagoBadge badge,
  ) {
    return InkWell(
      onTap: () => _openDocument(context, pago),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: shadow,
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: const Color(0xffe0f2fe),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long, color: Color(0xff0ea5e9)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pago.descripcion ?? 'Pago',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pago.fecha ?? pago.fechaEmision ?? pago.fechaVencimiento ?? '--',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badge.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badge.label,
                          style: TextStyle(
                            color: badge.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Ver documento',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: badge.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '\$${pago.monto ?? '--'}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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

  List<Pago> get _pagosPagados =>
      widget.inmueble.pagos.where((p) => _classifyPago(p) == _PagoState.paid).toList();

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
        return const Color(0xffef4444);
      case _PagoState.pending:
        return const Color(0xfff59e0b);
      case _PagoState.paid:
        return const Color(0xff16a34a);
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
