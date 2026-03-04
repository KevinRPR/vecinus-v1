import 'dart:ui';

import 'package:flutter/material.dart';

import '../animations/shimmers.dart';
import '../models/inmueble.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';
import '../preferences_controller.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../ui_system/components/app_empty_state.dart';
import '../ui_system/formatters/money.dart';
import '../ui_system/formatters/safe_text.dart';
import '../ui_system/perf/app_perf.dart';

class DashboardScreen extends StatelessWidget {
  final User user;
  final List<Inmueble> inmuebles;
  final bool loading;
  final Future<void> Function() onRefresh;
  final VoidCallback onViewPayments;
  final VoidCallback onViewAlerts;
  final DateTime? lastSync;

  const DashboardScreen({
    super.key,
    required this.user,
    required this.inmuebles,
    required this.loading,
    required this.onRefresh,
    required this.onViewPayments,
    required this.onViewAlerts,
    this.lastSync,
  });

  double get _totalDeuda => inmuebles.fold(
        0,
        (sum, item) => sum + _parseMonto(item.deudaActual),
      );

  double _parseMonto(String? raw) {
    if (raw == null) return 0;
    final cleaned = raw.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (cleaned.isEmpty) return 0;
    return double.tryParse(cleaned.replaceAll(',', '.')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final borderColor = theme.colorScheme.outline;
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.35 : 0.06);
    final textMuted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
            (isDark ? AppColors.darkTextMuted : AppColors.textMuted);
    final textStrong = theme.colorScheme.onSurface;

    return ValueListenableBuilder<UserPreferences>(
      valueListenable: preferencesController.preferences,
      builder: (context, prefs, _) {
        if (loading && inmuebles.isEmpty) {
          return Scaffold(
            backgroundColor: background,
            body: _loadingSkeleton(context),
          );
        }

        final statusCard = _buildStatusCard(
          cardColor: cardColor,
          borderColor: borderColor,
          shadowColor: shadowColor,
          textMuted: textMuted,
          textStrong: textStrong,
          isDark: isDark,
        );
        final breakdownCard = _buildDebtBreakdownCard(
          cardColor: cardColor,
          borderColor: borderColor,
          shadowColor: shadowColor,
          textMuted: textMuted,
          textStrong: textStrong,
        );
        final statusSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            statusCard,
            if (breakdownCard != null) ...[
              const SizedBox(height: 12),
              breakdownCard,
            ],
          ],
        );
        final announcementCard = _buildCommunityAnnouncementsSection(
          context: context,
          cardColor: cardColor,
          borderColor: borderColor,
          shadowColor: shadowColor,
          textMuted: textMuted,
          textStrong: textStrong,
          isDark: isDark,
        );
        final activitySection = _buildRecentActivitySection(
          cardColor: cardColor,
          borderColor: borderColor,
          shadowColor: shadowColor,
          textMuted: textMuted,
          textStrong: textStrong,
          isDark: isDark,
        );
        final cards = prefs.inmueble.cardOrder ==
                DashboardCardOrder.announcementsFirst
            ? [announcementCard, statusSection, activitySection]
            : [statusSection, announcementCard, activitySection];

        return Scaffold(
          backgroundColor: background,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _DashboardHeader(
                  user: user,
                  lastSync: lastSync,
                  isDark: isDark,
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        for (int i = 0; i < cards.length; i++) ...[
                          cards[i],
                          if (i != cards.length - 1)
                            const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _loadingSkeleton(BuildContext context) {
    final paddingTop = MediaQueryData.fromView(View.of(context)).padding.top;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, paddingTop + 12, 16, 24),
      child: const Column(
        children: [
          ShimmerSkeleton(
            height: 72,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          SizedBox(height: 16),
          ShimmerSkeleton(
            height: 160,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          SizedBox(height: 16),
          ShimmerSkeleton(
            height: 140,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard({
    required Color cardColor,
    required Color borderColor,
    required Color shadowColor,
    required Color textMuted,
    required Color textStrong,
    required bool isDark,
  }) {
    final totalDeuda = _totalDeuda;
    final isAlDia = totalDeuda <= 0;
    final inmuebleCount = inmuebles.length;
    final pendingCount =
        inmuebleCount - inmuebles.where((item) => _parseMonto(item.deudaActual) <= 0).length;
    final title = isAlDia ? 'Estas al dia' : 'Deuda total';
    final subtitle = isAlDia
        ? 'Sin deudas pendientes'
        : '$pendingCount con deuda';
    final statusColor = isAlDia ? AppColors.success : AppColors.warning;
    final statusIcon =
        isAlDia ? IconsRounded.check_circle : IconsRounded.warning_rounded;

    return _glassCard(
      color: cardColor,
      borderColor: borderColor,
      shadowColor: shadowColor,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textStrong,
                  ),
                ),
                if (!isAlDia) ...[
                  const SizedBox(height: 6),
                  Text(
                    _formatCurrency(totalDeuda),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textStrong,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _PrimaryPillButton(
            label: 'Ver pagos',
            onTap: onViewPayments,
            dense: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityAnnouncementsSection({
    required BuildContext context,
    required Color cardColor,
    required Color borderColor,
    required Color shadowColor,
    required Color textMuted,
    required Color textStrong,
    required bool isDark,
  }) {
    final totalAlerts = NotificationService.all().length;
    final newLabel =
        totalAlerts == 1 ? '1 Nueva' : '$totalAlerts Nuevas';
    final highlights = _notificationHighlights();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Alertas importantes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textStrong,
              ),
            ),
            if (totalAlerts > 0) ...[
              const SizedBox(width: 8),
              _alertBadge(newLabel),
            ],
            const Spacer(),
            _ActionLink(
              label: 'Ver',
              onTap: onViewAlerts,
              color: AppColors.brandBlue600,
              fontSize: 12,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (highlights.isEmpty)
          const AppEmptyState(
            icon: IconsRounded.notifications_off,
            title: 'No hay alertas importantes.',
            subtitle: 'Te avisaremos cuando exista una novedad.',
          )
        else
          Column(
            children: [
              for (int i = 0; i < highlights.length; i++) ...[
                _alertCard(
                  highlights[i],
                  cardColor: cardColor,
                  borderColor: borderColor,
                  shadowColor: shadowColor,
                  textMuted: textMuted,
                  textStrong: textStrong,
                  onTap: onViewAlerts,
                  isDark: isDark,
                ),
                if (i != highlights.length - 1)
                  const SizedBox(height: 12),
              ],
            ],
          ),
        const SizedBox(height: 14),
        _communityActionCard(
          cardColor: cardColor,
          borderColor: borderColor,
          shadowColor: shadowColor,
          textMuted: textMuted,
          textStrong: textStrong,
          isDark: isDark,
          onParticipate: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Disponible pronto.')),
            );
          },
        ),
      ],
    );
  }

  Widget _alertBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.error,
        ),
      ),
    );
  }

  Widget? _buildDebtBreakdownCard({
    required Color cardColor,
    required Color borderColor,
    required Color shadowColor,
    required Color textMuted,
    required Color textStrong,
  }) {
    if (inmuebles.isEmpty) return null;

    final items = inmuebles.toList()
      ..sort(
        (a, b) => _parseMonto(b.deudaActual).compareTo(_parseMonto(a.deudaActual)),
      );

    return _glassCard(
      color: cardColor,
      borderColor: borderColor,
      shadowColor: shadowColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalle por inmueble',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textStrong,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Inmueble',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textMuted,
                  ),
                ),
              ),
              Text(
                'Deuda',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < items.length; i++) ...[
            _buildDebtRow(
              items[i],
              textMuted: textMuted,
              textStrong: textStrong,
            ),
            if (i != items.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(
                  height: 1,
                  color: borderColor.withValues(alpha: 0.6),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDebtRow(
    Inmueble item, {
    required Color textMuted,
    required Color textStrong,
  }) {
    final title = _inmuebleTitle(item);
    final subtitle = _inmuebleSubtitle(item);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textStrong,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _formatCurrency(_parseMonto(item.deudaActual)),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textStrong,
          ),
        ),
      ],
    );
  }

  String _inmuebleTitle(Inmueble item) {
    final ident = safeTextOrEmpty(item.identificacion);
    if (ident.isNotEmpty) return ident;
    final correlativo = safeTextOrEmpty(item.correlativo);
    if (correlativo.isNotEmpty) return correlativo;
    return 'Inmueble ${item.idInmueble}';
  }

  String _inmuebleSubtitle(Inmueble item) {
    final condo = safeTextOrEmpty(item.nombreCondominio);
    if (condo.isNotEmpty) return condo;
    final tipo = safeTextOrEmpty(item.tipo);
    if (tipo.isNotEmpty) return tipo;
    return '';
  }

  Widget _alertCard(
    AppNotification notification, {
    required Color cardColor,
    required Color borderColor,
    required Color shadowColor,
    required Color textMuted,
    required Color textStrong,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final iconColor = _kindColor(notification.kind);
    final icon = _kindIcon(notification.kind);
    final title = safeText(notification.title, fallback: 'Aviso');
    final subtitle = safeTextOrEmpty(notification.subtitle);

    return _glassCard(
      color: cardColor,
      borderColor: borderColor,
      shadowColor: shadowColor,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textStrong,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ActionLink(
            label: 'Ver',
            onTap: onTap,
            color: AppColors.brandBlue600,
            fontSize: 12,
          ),
        ],
      ),
    );
  }

  Widget _communityActionCard({
    required Color cardColor,
    required Color borderColor,
    required Color shadowColor,
    required Color textMuted,
    required Color textStrong,
    required bool isDark,
    required VoidCallback onParticipate,
  }) {
    return _glassCard(
      color: cardColor,
      borderColor: borderColor,
      shadowColor: shadowColor,
      padding: const EdgeInsets.all(14),
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
              IconsRounded.campaign,
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
                  'Tu opinion construye comunidad',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textStrong,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nueva votacion disponible para el color de la fachada.',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: onParticipate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: textStrong,
                      foregroundColor: ThemeData.estimateBrightnessForColor(
                                  textStrong) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Participar ahora  ->'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection({
    required Color cardColor,
    required Color borderColor,
    required Color shadowColor,
    required Color textMuted,
    required Color textStrong,
    required bool isDark,
  }) {
    final recent = NotificationService.all().toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final items = recent.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Actividad reciente',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textStrong,
              ),
            ),
            const Spacer(),
            _ActionLink(
              label: 'Ver todo',
              onTap: onViewAlerts,
              color: AppColors.brandBlue600,
              fontSize: 12,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _glassCard(
          color: cardColor,
          borderColor: borderColor,
          shadowColor: shadowColor,
          padding: const EdgeInsets.all(14),
          child: items.isEmpty
              ? Text(
                  'No hay actividad reciente.',
                  style: TextStyle(color: textMuted),
                )
              : Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      _buildActivityRow(
                        items[i],
                        textMuted: textMuted,
                        textStrong: textStrong,
                      ),
                      if (i != items.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Divider(
                            height: 1,
                            color: borderColor.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildActivityRow(
    AppNotification item, {
    required Color textMuted,
    required Color textStrong,
  }) {
    final iconColor = _kindColor(item.kind);
    final icon = _kindIcon(item.kind);
    final timeLabel = _activityTimeLabel(item.timestamp);

    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textStrong,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          timeLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textMuted,
          ),
        ),
      ],
    );
  }

  List<AppNotification> _notificationHighlights() {
    final items = NotificationService.all().toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items.take(2).toList();
  }

  Color _kindColor(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.warning:
        return AppColors.warning;
      case NotificationKind.event:
        return AppColors.info;
      case NotificationKind.info:
        return AppColors.success;
    }
  }

  IconData _kindIcon(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.warning:
        return IconsRounded.warning_rounded;
      case NotificationKind.event:
        return IconsRounded.event;
      case NotificationKind.info:
        return IconsRounded.notifications;
    }
  }

  String _activityTimeLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);
    if (date == today) return 'HOY';
    if (date == today.subtract(const Duration(days: 1))) return 'AYER';
    return _formatShortDate(time);
  }

  String _formatShortDate(DateTime value) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final day = value.day.toString().padLeft(2, '0');
    return '$day ${months[value.month - 1]}';
  }


  Widget _glassCard({
    required Widget child,
    required Color color,
    required Color borderColor,
    required Color shadowColor,
    EdgeInsets? padding,
    double radius = 16,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  String _formatCurrency(double value) {
    return formatMoney(value);
  }
}

class _DashboardHeader extends StatelessWidget {
  final User user;
  final DateTime? lastSync;
  final bool isDark;

  const _DashboardHeader({
    required this.user,
    required this.lastSync,
    required this.isDark,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme = Theme.of(context);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final backgroundColor =
        theme.scaffoldBackgroundColor.withValues(alpha: 0.92);
    final textMuted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
            (isDark ? AppColors.darkTextMuted : AppColors.textMuted);
    final syncLabel =
        lastSync == null ? 'Sin actualizar' : _formatLastSync(lastSync!);

    final titleStyle = theme.appBarTheme.titleTextStyle ??
        theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);

    final blurSigma = AppPerf.blurSigma(context, 18);
    final headerContent = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Inicio', style: titleStyle),
              _buildAvatar(isDark),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(
                child: Text(
                  'Hola, ${user.displayName}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: textMuted.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Icon(IconsRounded.history, size: 12, color: textMuted),
              const SizedBox(width: 4),
              Text(
                syncLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return ClipRect(
      child: blurSigma == 0
          ? headerContent
          : BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: headerContent,
            ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    final avatarUrl = user.avatarUrl;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    return Semantics(
      label: 'Perfil activo',
      child: SizedBox(
        height: 42,
        width: 42,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: ClipOval(
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _fallbackAvatar();
                    },
                  )
                : _fallbackAvatar(),
          ),
        ),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: AppColors.brandBlue600.withValues(alpha: 0.12),
      child: const Icon(
        IconsRounded.person,
        color: AppColors.brandBlue600,
        size: 22,
      ),
    );
  }
}

class _PrimaryPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool dense;

  const _PrimaryPillButton({
    required this.label,
    required this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final padding = dense
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 8);
    final fontSize = dense ? 12.0 : 13.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.brandBlue600,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandBlue600.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ActionLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final double fontSize;

  const _ActionLink({
    required this.label,
    required this.onTap,
    required this.color,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

String _formatLastSync(DateTime value) {
  final now = DateTime.now();
  final isToday =
      value.year == now.year && value.month == now.month && value.day == now.day;
  String two(int n) => n.toString().padLeft(2, '0');
  final time = '${two(value.hour)}:${two(value.minute)}';
  if (isToday) return 'Hoy $time';
  return '${two(value.day)}/${two(value.month)} $time';
}
