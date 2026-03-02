import 'package:flutter/material.dart';

import '../models/inmueble.dart';
import '../theme/app_theme.dart';
import '../ui_system/components/app_kv_row.dart';
import '../ui_system/components/app_status_chip.dart';
import '../ui_system/formatters/percent.dart';
import '../ui_system/formatters/safe_text.dart';
import 'payment_detail_screen.dart';

class InmuebleDetailScreen extends StatelessWidget {
  final Inmueble inmueble;
  final String? token;

  const InmuebleDetailScreen({
    super.key,
    required this.inmueble,
    this.token,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _statusForInmueble(inmueble);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          safeText(
            inmueble.identificacion,
            fallback: 'Detalle del inmueble',
          ),
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _headerCard(context, status),
          const SizedBox(height: 16),
          _accionesSection(context),
          const SizedBox(height: 20),
          _documentosSection(context),
          const SizedBox(height: 20),
          _detallesSection(context),
        ],
      ),
    );
  }

  Widget _headerCard(BuildContext context, AppStatus status) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: AppColors.brandBlue600.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            IconsRounded.home_work,
            color: AppColors.brandBlue600,
            size: 28,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          safeText(inmueble.identificacion, fallback: 'Inmueble'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _condominioLabel(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        AppStatusChip(status: status),
      ],
    );
  }

  Widget _accionesSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppColors.textMuted;
    final hasToken = token != null && token!.trim().isNotEmpty;

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estado de cuenta y pagos',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasToken
                ? 'Consulta saldos, reportes e historial desde la pantalla de pagos.'
                : 'Inicia sesion para consultar el estado de cuenta.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: hasToken ? () => _openPaymentDetail(context) : null,
              icon: const Icon(IconsRounded.payments),
              label: const Text('Ver estado de cuenta'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentosSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documentos y acuerdos',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _documentTile(
                context,
                icon: IconsRounded.description,
                label: 'Acuerdos\nConvivencia',
                enabled: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _documentTile(
                context,
                icon: IconsRounded.home,
                label: 'Ficha\nCatastral',
                enabled: false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _documentTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    final muted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppColors.textMuted;

    return InkWell(
      onTap: enabled
          ? () {}
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Documento no disponible.')),
              );
            },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: AppColors.brandBlue600.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.brandBlue600, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? theme.colorScheme.onSurface : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detallesSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalles de propiedad',
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
          ),
          child: Column(
            children: [
              AppKvRow(label: 'Direccion', value: _direccion(inmueble)),
              const SizedBox(height: 8),
              Divider(color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              AppKvRow(
                label: 'Alicuota',
                value: _formatAlicuota(inmueble.alicuota),
              ),
              const SizedBox(height: 8),
              Divider(color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              AppKvRow(
                label: 'ID inmueble',
                value: safeText(inmueble.idInmueble),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openPaymentDetail(BuildContext context) {
    final value = token;
    if (value == null || value.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesion para ver el detalle.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentDetailScreen(
          inmueble: inmueble,
          token: value,
          totalDeuda: _parseMonto(inmueble.deudaActual),
        ),
      ),
    );
  }

  AppStatus _statusForInmueble(Inmueble inmueble) {
    switch (inmueble.estado) {
      case EstadoInmueble.alDia:
        return AppStatus.alDia;
      case EstadoInmueble.moroso:
        return AppStatus.atrasado;
      case EstadoInmueble.pendiente:
        return AppStatus.pendiente;
      case EstadoInmueble.desconocido:
        return AppStatus.pendiente;
    }
  }

  String _condominioLabel() {
    final nombre = inmueble.nombreCondominio;
    if (nombre != null && nombre.trim().isNotEmpty) {
      return nombre.trim();
    }
    return 'Condominio #${inmueble.idCondominio}';
  }

  String _direccion(Inmueble i) {
    if (i.tipo?.toLowerCase() == 'apartamento') {
      final torre = safeTextOrEmpty(i.torre);
      final piso = safeTextOrEmpty(i.piso);
      final parts = <String>[];
      if (torre.isNotEmpty) parts.add('Torre $torre');
      if (piso.isNotEmpty) parts.add('Piso $piso');
      return parts.isEmpty ? 'No disponible' : parts.join(', ');
    }
    final calle = safeTextOrEmpty(i.calle);
    final manzana = safeTextOrEmpty(i.manzana);
    final casa = safeTextOrEmpty(i.identificacion);
    final parts = <String>[];
    if (calle.isNotEmpty) parts.add('Calle $calle');
    if (manzana.isNotEmpty) parts.add('Mz $manzana');
    if (casa.isNotEmpty) parts.add('Casa $casa');
    return parts.isEmpty ? 'No disponible' : parts.join(', ');
  }

  String _formatAlicuota(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'No disponible';
    }
    final sanitized =
        raw.replaceAll(RegExp(r'[^0-9.,-]'), '').replaceAll(',', '.');
    final value = double.tryParse(sanitized);
    if (value == null) {
      return safeText(raw);
    }
    return formatPercent(value, includeSymbol: false);
  }

  double _parseMonto(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    final sanitized =
        raw.replaceAll(RegExp(r'[^0-9.,-]'), '').replaceAll(',', '.');
    return double.tryParse(sanitized) ?? 0;
  }
}
