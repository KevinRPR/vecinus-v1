import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../ui_system/components/app_icon_button.dart';

class GenerateReportScreen extends StatefulWidget {
  const GenerateReportScreen({super.key});

  @override
  State<GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends State<GenerateReportScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  String _property = 'Todas las unidades';
  String _reportType = 'resumen';

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _from = picked);
    }
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _to = picked);
    }
  }

  String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
            AppColors.textMuted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar reporte'),
        actions: [
          AppIconButton(
            icon: IconsRounded.help_outline,
            tooltip: 'Ayuda',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configura los filtros del reporte.')),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            'Configura los filtros para exportar el reporte de pagos de tu comunidad.',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 16),
          _card(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(
                  context,
                  icon: IconsRounded.calendar_month,
                  title: 'Rango de fechas',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _dateField(
                        context,
                        label: 'DESDE',
                        value: _formatDate(_from),
                        onTap: _pickFrom,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dateField(
                        context,
                        label: 'HASTA',
                        value: _formatDate(_to),
                        onTap: _pickTo,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(
                  context,
                  icon: IconsRounded.home_work,
                  title: 'Propiedad',
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _property,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'Todas las unidades',
                          child: Text('Todas las unidades'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _property = value);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(
                  context,
                  icon: IconsRounded.description,
                  title: 'Tipo de reporte',
                ),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: _reportType,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _reportType = value);
                    }
                  },
                  child: Column(
                    children: [
                      _radioOption(
                        context,
                        value: 'resumen',
                        label: 'Resumen de pagos recibidos',
                      ),
                      _radioOption(
                        context,
                        value: 'pendientes',
                        label: 'Deudas pendientes por unidad',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(IconsRounded.insert_chart),
            label: const Text('Generar reporte'),
          ),
        ],
      ),
    );
  }

  Widget _cardTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _cardHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: AppColors.brandBlue600.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.brandBlue600,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        _cardTitle(context, title),
      ],
    );
  }

  Widget _dateField(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final muted =
        Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
            AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w700),
          suffixIcon: const Icon(IconsRounded.calendar_month),
        ),
        child: Text(value),
      ),
    );
  }

  Widget _radioOption(
    BuildContext context, {
    required String value,
    required String label,
  }) {
    final registry = RadioGroup.maybeOf<String>(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: registry == null ? null : () => registry.onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Radio<String>(
              value: value,
              activeColor: AppColors.brandBlue600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: child,
    );
  }
}
