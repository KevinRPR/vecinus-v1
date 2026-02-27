import 'dart:ui';

import 'package:flutter/material.dart';

import '../animations/shimmers.dart';
import '../models/inmueble.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';
import '../preferences_controller.dart';
import '../services/notification_service.dart';

const _primary = Color(0xff548C8C);
const _cardLight = Color(0xCCFFFFFF);
const _cardDark = Color(0xCC1E1E1E);
const _textDark = Color(0xff0F172A);
const _textMutedLight = Color(0xff64748B);
const _textMutedDark = Color(0xff94A3B8);
const double _glassBlur = 12;

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
    final cardColor = isDark ? _cardDark : _cardLight;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.45);
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.35 : 0.06);
    final textMuted = isDark ? _textMutedDark : _textMutedLight;
    final textStrong = isDark ? Colors.white : _textDark;

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
          compactSummary: prefs.inmueble.compactSummary,
        );
        final announcementCard = _buildCommunityAnnouncementsSection(
          cardColor: cardColor,
          borderColor: borderColor,
          shadowColor: shadowColor,
          textMuted: textMuted,
          textStrong: textStrong,
          isDark: isDark,
        );
        final cards = prefs.inmueble.cardOrder ==
                DashboardCardOrder.announcementsFirst
            ? [announcementCard, statusCard]
            : [statusCard, announcementCard];

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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
    required bool compactSummary,
  }) {
    final totalDeuda = _totalDeuda;
    final isAlDia = totalDeuda <= 0;
    final inmuebleCount = inmuebles.length;
    final paidCount =
        inmuebles.where((item) => _parseMonto(item.deudaActual) <= 0).length;
    final pendingCount = inmuebleCount - paidCount;
    final breakdownItems = _debtBreakdownItems();
    final shownBreakdown = breakdownItems.take(6).toList();
    final remainingBreakdown = breakdownItems.length - shownBreakdown.length;
    final title = isAlDia ? 'Estas al dia' : 'Total adeudado';
    final subtitle = isAlDia
        ? 'Sin deudas pendientes en tus inmuebles'
        : '$pendingCount con deuda de $inmuebleCount inmuebles';
    final statusColor =
        isAlDia ? const Color(0xff0D9488) : const Color(0xffF59E0B);
    final progress = inmuebleCount == 0
        ? 0.0
        : (paidCount / inmuebleCount).clamp(0.0, 1.0);
    final progressLabel = '${(progress * 100).round()}%';
    final dividerColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06);
    final analysisPaperBackground =
        isDark ? const Color(0xff1B2730) : const Color(0xffF1F4F8);
    final analysisPaperLineColor =
        isDark ? const Color(0xff86B3B3) : _primary;
    final analysisPaperBorder =
        isDark ? Colors.white.withValues(alpha: 0.18) : _primary.withValues(alpha: 0.18);
    final rowDividerColor =
        isDark ? Colors.white.withValues(alpha: 0.35) : _primary.withValues(alpha: 0.45);

    return _glassCard(
      color: cardColor,
      borderColor: borderColor,
      shadowColor: shadowColor,
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 280;
          final actionButton = _PrimaryPillButton(
            label: 'Ver pagos',
            onTap: onViewPayments,
            dense: isCompact,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textStrong,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatCurrency(totalDeuda),
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: textStrong,
                          ),
                        ),
                        const SizedBox(height: 6),
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
                  SizedBox(
                    height: 64,
                    width: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 7,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            statusColor.withValues(alpha: 0.85),
                          ),
                          backgroundColor:
                              statusColor.withValues(alpha: 0.12),
                        ),
                        Text(
                          progressLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatusMetric(
                      label: 'Inmuebles',
                      value: inmuebleCount.toString(),
                      textMuted: textMuted,
                      textStrong: textStrong,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatusMetric(
                      label: 'Con deuda',
                      value: pendingCount.toString(),
                      textMuted: textMuted,
                      textStrong: textStrong,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: actionButton,
              ),
              if (!compactSummary && shownBreakdown.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(height: 1, color: dividerColor),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Desglose por inmueble',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _AnalysisPaper(
                  backgroundColor: analysisPaperBackground,
                  lineColor: analysisPaperLineColor,
                  borderColor: analysisPaperBorder,
                  child: Column(
                    children: [
                      for (int i = 0; i < shownBreakdown.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: _buildBreakdownRow(
                            shownBreakdown[i],
                            textStrong: textStrong,
                            textMuted: textMuted,
                          ),
                        ),
                        if (i != shownBreakdown.length - 1)
                          Container(height: 1.2, color: rowDividerColor),
                      ],
                    ],
                  ),
                ),
                if (remainingBreakdown > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'y $remainingBreakdown inmuebles mas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCommunityAnnouncementsSection({
    required Color cardColor,
    required Color borderColor,
    required Color shadowColor,
    required Color textMuted,
    required Color textStrong,
    required bool isDark,
  }) {
    final highlight = _pickAnnouncementHighlight();

    return _glassCard(
      color: cardColor,
      borderColor: borderColor,
      shadowColor: shadowColor,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _buildAnnouncementRow(
            icon: highlight.icon,
            iconColor: highlight.iconColor,
            iconBackground: highlight.iconBackground,
            title: highlight.title,
            headline: highlight.headline,
            subtitle: 'Inmueble: ${highlight.sourceLabel}',
            actionLabel: highlight.actionLabel,
            onTap: onViewAlerts,
            textMuted: textMuted,
            textStrong: textStrong,
            isDark: isDark,
            compact: true,
            showSubtitle: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String headline,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
    required Color textMuted,
    required Color textStrong,
    required bool isDark,
    bool compact = false,
    bool showSubtitle = true,
  }) {
    final iconSize = compact ? 34.0 : 40.0;
    final iconRadius = compact ? 10.0 : 12.0;
    final iconSymbolSize = compact ? 16.0 : 20.0;
    final titleSize = compact ? 13.0 : 14.0;
    final headlineSize = compact ? 13.0 : 14.0;
    final subtitleSize = compact ? 12.0 : 13.0;
    final spacing = compact ? 8.0 : 12.0;
    final linkSize = compact ? 12.0 : 13.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: iconSize,
          width: iconSize,
          decoration: BoxDecoration(
            color: iconBackground.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(iconRadius),
          ),
          child: Icon(icon, color: iconColor, size: iconSymbolSize),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        color: textStrong,
                      ),
                    ),
                  ),
                  _ActionLink(
                    label: actionLabel,
                    onTap: onTap,
                    color: _primary,
                    fontSize: linkSize,
                  ),
                ],
              ),
              SizedBox(height: compact ? 4 : 6),
              Text(
                headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: headlineSize,
                  fontWeight: FontWeight.w600,
                  color: textStrong,
                ),
              ),
              if (showSubtitle) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: subtitleSize, color: textMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusMetric({
    required String label,
    required String value,
    required Color textMuted,
    required Color textStrong,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textStrong,
          ),
        ),
      ],
    );
  }

  Widget _statusPill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(
    _DebtItem item, {
    required Color textStrong,
    required Color textMuted,
  }) {
    final amountColor = item.amount > 0 ? textStrong : textMuted;
    return Row(
      children: [
        Expanded(
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textStrong,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatCurrency(item.amount),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: amountColor,
          ),
        ),
      ],
    );
  }

  List<AppNotification> _notificationsByKind(NotificationKind kind) {
    final items = NotificationService.all()
        .where((notification) => notification.kind == kind)
        .toList();
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  _AnnouncementHighlight _pickAnnouncementHighlight() {
    final alerts = _notificationsByKind(NotificationKind.warning);
    if (alerts.isNotEmpty) {
      final notification = alerts.first;
      return _AnnouncementHighlight(
        icon: Icons.notifications,
        iconColor: const Color(0xffF59E0B),
        iconBackground: const Color(0xffF59E0B),
        title: 'Alerta importante',
        headline: _notificationHeadline(
          notification,
          fallback: 'Nueva alerta en tu comunidad',
        ),
        sourceLabel: _notificationSourceLabel(notification),
        actionLabel: 'Ver',
      );
    }

    final events = _notificationsByKind(NotificationKind.event);
    if (events.isNotEmpty) {
      final notification = events.first;
      return _AnnouncementHighlight(
        icon: Icons.event_available,
        iconColor: const Color(0xff14B8A6),
        iconBackground: const Color(0xff14B8A6),
        title: 'Evento proximo',
        headline: _notificationHeadline(
          notification,
          fallback: 'Evento · ${_formatDateTime(notification.timestamp)}',
        ),
        sourceLabel: _notificationSourceLabel(notification),
        actionLabel: 'Ver calendario',
      );
    }

    final notices = _notificationsByKind(NotificationKind.info);
    if (notices.isNotEmpty) {
      final notification = notices.first;
      return _AnnouncementHighlight(
        icon: Icons.campaign,
        iconColor: const Color(0xff3B82F6),
        iconBackground: const Color(0xff3B82F6),
        title: 'Aviso destacado',
        headline: _notificationHeadline(
          notification,
          fallback: 'Nuevo aviso del administrador',
        ),
        sourceLabel: _notificationSourceLabel(notification),
        actionLabel: 'Ver avisos',
      );
    }

    return _AnnouncementHighlight(
      icon: Icons.campaign,
      iconColor: const Color(0xff94A3B8),
      iconBackground: const Color(0xff94A3B8),
      title: 'Anuncio destacado',
      headline: 'No hay anuncios recientes.',
      sourceLabel: _notificationSourceLabel(null),
      actionLabel: 'Ver avisos',
    );
  }

  String _notificationHeadline(
    AppNotification notification, {
    required String fallback,
  }) {
    final title = notification.title.trim();
    if (title.isNotEmpty) return title;
    final subtitle = notification.subtitle.trim();
    if (subtitle.isNotEmpty) return subtitle;
    return fallback;
  }

  String _notificationSourceLabel(AppNotification? notification) {
    if (inmuebles.isEmpty) return 'Sin inmueble';
    final labels = inmuebles.map(_inmuebleLabel).toList(growable: false);
    if (notification != null) {
      final haystack =
          '${notification.title} ${notification.subtitle}'.toLowerCase();
      for (final label in labels) {
        final normalized = label.toLowerCase();
        if (normalized.isNotEmpty && haystack.contains(normalized)) {
          return label;
        }
      }
    }
    final breakdown = _debtBreakdownItems();
    if (breakdown.isNotEmpty) return breakdown.first.label;
    return labels.first;
  }

  List<_DebtItem> _debtBreakdownItems() {
    if (inmuebles.isEmpty) return <_DebtItem>[];
    final items = inmuebles
        .map(
          (inmueble) => _DebtItem(
            label: _inmuebleLabel(inmueble),
            amount: _parseMonto(inmueble.deudaActual),
          ),
        )
        .toList();
    items.sort((a, b) => b.amount.compareTo(a.amount));
    return items;
  }

  String _inmuebleLabel(Inmueble inmueble) {
    final identificacion = inmueble.identificacion?.trim();
    if (identificacion != null && identificacion.isNotEmpty) {
      return identificacion;
    }
    final correlativo = inmueble.correlativo?.trim();
    if (correlativo != null && correlativo.isNotEmpty) {
      return 'Inmueble $correlativo';
    }
    final torre = inmueble.torre?.trim();
    final piso = inmueble.piso?.trim();
    if (torre != null && torre.isNotEmpty && piso != null && piso.isNotEmpty) {
      return 'Torre $torre - Piso $piso';
    }
    final nombre = inmueble.nombreCondominio?.trim();
    if (nombre != null && nombre.isNotEmpty) {
      return nombre;
    }
    return 'Inmueble ${inmueble.idInmueble}';
  }

  String _formatDateTime(DateTime value) {
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
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(value.hour)}:${two(value.minute)}';
    return '${two(value.day)} ${months[value.month - 1]} ${value.year} · $time';
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
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _glassBlur, sigmaY: _glassBlur),
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
      ),
    );
  }

  String _formatCurrency(double value) {
    return '\$${value.toStringAsFixed(2)}';
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
    final dotBorderColor = theme.scaffoldBackgroundColor;
    final textMuted = isDark ? _textMutedDark : _textMutedLight;
    final textStrong = isDark ? Colors.white : _textDark;
    final syncLabel =
        lastSync == null ? 'Sin actualizar' : _formatLastSync(lastSync!);

    return SizedBox(
      height: 118,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Inicio',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: textStrong,
                      ),
                    ),
                    Row(
                      children: [
                        _buildAvatar(isDark, dotBorderColor),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Hola, ${user.displayName}',
                        style: TextStyle(
                          fontSize: 16,
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
                    Icon(Icons.history, size: 12, color: textMuted),
                    const SizedBox(width: 4),
                    Text(
                      syncLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isDark, Color dotBorderColor) {
    final avatarUrl = user.avatarUrl;
    final borderColor = isDark ? const Color(0xff334155) : Colors.white;
    return SizedBox(
      height: 42,
      width: 42,
      child: Stack(
        children: [
          Container(
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
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xff22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: dotBorderColor, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: _primary.withValues(alpha: 0.12),
      child: const Icon(
        Icons.person,
        color: _primary,
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
          color: _primary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.25),
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

class _DebtItem {
  final String label;
  final double amount;

  _DebtItem({required this.label, required this.amount});
}

class _AnnouncementHighlight {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String headline;
  final String sourceLabel;
  final String actionLabel;

  const _AnnouncementHighlight({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.headline,
    required this.sourceLabel,
    required this.actionLabel,
  });
}

class _AnalysisPaper extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color lineColor;
  final Color borderColor;

  const _AnalysisPaper({
    required this.child,
    required this.backgroundColor,
    required this.lineColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(
        painter: _AnalysisPaperPainter(
          lineColor: lineColor,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: child,
        ),
      ),
    );
  }

}

class _AnalysisPaperPainter extends CustomPainter {
  final Color lineColor;
  final double gridSize;
  final double minorWidth;
  final double majorWidth;
  final int majorInterval;

  _AnalysisPaperPainter({
    required this.lineColor,
    this.gridSize = 12,
    this.minorWidth = 0.6,
    this.majorWidth = 1.0,
    this.majorInterval = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..strokeWidth = minorWidth;
    final majorPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.55)
      ..strokeWidth = majorWidth;

    int lineIndex = 0;
    for (double x = 0; x <= size.width; x += gridSize) {
      final paint = (lineIndex % majorInterval == 0) ? majorPaint : minorPaint;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      lineIndex += 1;
    }

    lineIndex = 0;
    for (double y = 0; y <= size.height; y += gridSize) {
      final paint = (lineIndex % majorInterval == 0) ? majorPaint : minorPaint;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      lineIndex += 1;
    }
  }

  @override
  bool shouldRepaint(covariant _AnalysisPaperPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.gridSize != gridSize ||
        oldDelegate.minorWidth != minorWidth ||
        oldDelegate.majorWidth != majorWidth ||
        oldDelegate.majorInterval != majorInterval;
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
