import 'package:flutter/material.dart';

import '../models/inmueble.dart';
import '../theme/app_theme.dart';
import '../ui_system/components/app_kv_row.dart';
import '../ui_system/formatters/percent.dart';
import '../ui_system/formatters/safe_text.dart';

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
          _headerCard(context),
          const SizedBox(height: 20),
          _detallesSection(context),
          const SizedBox(height: 20),
          _documentosSection(context),
        ],
      ),
    );
  }

  Widget _headerCard(BuildContext context) {
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
      ],
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
    final entries = <MapEntry<String, String>>[
      MapEntry('Direccion', _direccion(inmueble)),
      MapEntry('Tipo', safeTextOrEmpty(inmueble.tipo)),
      MapEntry('Torre', safeTextOrEmpty(inmueble.torre)),
      MapEntry('Piso', safeTextOrEmpty(inmueble.piso)),
      MapEntry('Manzana', safeTextOrEmpty(inmueble.manzana)),
      MapEntry('Avenida', safeTextOrEmpty(inmueble.avenida)),
      MapEntry('Correlativo', safeTextOrEmpty(inmueble.correlativo)),
      MapEntry('Alicuota', _formatAlicuota(inmueble.alicuota)),
      MapEntry('ID inmueble', safeText(inmueble.idInmueble)),
      MapEntry('ID condominio', safeText(inmueble.idCondominio)),
    ];
    final filtered = entries.where((entry) {
      final value = entry.value.trim();
      if (value.isEmpty) return false;
      if (value == 'No disponible' &&
          entry.key != 'Direccion' &&
          entry.key != 'Alicuota') {
        return false;
      }
      return true;
    }).toList();

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
              for (int i = 0; i < filtered.length; i++) ...[
                AppKvRow(
                  label: filtered[i].key,
                  value: filtered[i].value,
                ),
                if (i != filtered.length - 1) ...[
                  const SizedBox(height: 8),
                  Divider(color: theme.colorScheme.outline),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ],
    );
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

}
