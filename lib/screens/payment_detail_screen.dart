import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/inmueble.dart';
import '../models/pago.dart';
import '../services/api_service.dart';

class PaymentDetailScreen extends StatelessWidget {
  final Inmueble inmueble;
  final double totalDeuda;

  const PaymentDetailScreen({
    super.key,
    required this.inmueble,
    required this.totalDeuda,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final shadow =
        Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.08);
    final muted =
        theme.textTheme.bodyMedium?.color?.withOpacity(0.65) ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de pago'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _headerCard(cardColor, shadow, muted, theme),
          const SizedBox(height: 20),
          _deudaCard(cardColor, shadow, muted),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _reportarPago(context),
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Reportar pago'),
          ),
          const SizedBox(height: 24),
          Text(
            'Desglose de la deuda',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (inmueble.pagos.isEmpty)
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
                'No hay pagos registrados para este inmueble.',
                style: TextStyle(color: muted),
              ),
            )
          else
            Column(
              children: inmueble.pagos
                  .map(
                    (pago) => _pagoTile(
                      context,
                      pago,
                      cardColor,
                      shadow,
                      muted,
                    ),
                  )
                  .toList(),
            ),
        ],
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
                      inmueble.identificacion ?? 'Inmueble',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            inmueble.tipo ?? 'Propiedad',
            style: TextStyle(color: muted),
          ),
        ],
      ),
    );
  }

  Widget _deudaCard(Color cardColor, Color shadow, Color muted) {
    final double deuda = totalDeuda < 0 ? 0.0 : totalDeuda;
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
          const Text(
            'Para estar solvente solo debe pagar',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(deuda),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.event_available, color: Color(0xff1d9bf0)),
              const SizedBox(width: 8),
              Text(
                'Proximo pago: ${inmueble.proximaFechaPago?.isNotEmpty == true ? inmueble.proximaFechaPago : '--'}',
                style: TextStyle(color: muted),
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
                    pago.fecha ?? '--',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _estadoColor(pago.estado).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          pago.estado ?? 'Estado',
                          style: TextStyle(
                            color: _estadoColor(pago.estado),
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
                            color: _estadoColor(pago.estado),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reportar pago aun no esta disponible.'),
      ),
    );
  }

  String _condominioLabel() {
    final nombre = inmueble.nombreCondominio;
    if (nombre != null && nombre.trim().isNotEmpty) {
      return nombre.trim();
    }
    return 'Condominio #${inmueble.idCondominio}';
  }

  String _formatCurrency(double value) => '\$${value.toStringAsFixed(2)}';

  Color _estadoColor(String? estado) {
    final value = (estado ?? '').toLowerCase();
    if (value.contains('pend')) return const Color(0xfff59e0b);
    if (value.contains('parcial')) return const Color(0xff2563eb);
    if (value.contains('pag')) return const Color(0xff16a34a);
    return Colors.blueGrey;
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
