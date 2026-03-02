import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum AppStatus { alDia, atrasado, pendiente, enProceso }

class AppStatusChip extends StatelessWidget {
  final AppStatus status;
  final String? labelOverride;
  final bool compact;

  const AppStatusChip({
    super.key,
    required this.status,
    this.labelOverride,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = _statusStyles(status);
    final text = labelOverride ?? resolved.label;
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
    final fontSize = compact ? 10.0 : 11.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: resolved.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: resolved.color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: resolved.color,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

class _StatusStyle {
  final String label;
  final Color color;

  const _StatusStyle(this.label, this.color);
}

_StatusStyle _statusStyles(AppStatus status) {
  switch (status) {
    case AppStatus.alDia:
      return const _StatusStyle('AL DIA', AppColors.success);
    case AppStatus.atrasado:
      return const _StatusStyle('ATRASADO', AppColors.error);
    case AppStatus.pendiente:
      return const _StatusStyle('PENDIENTE', AppColors.warning);
    case AppStatus.enProceso:
      return const _StatusStyle('EN PROCESO', AppColors.info);
  }
}

