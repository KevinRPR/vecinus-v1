import 'package:flutter/material.dart';

import '../animations/transitions.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../ui_system/components/app_empty_state.dart';
import '../ui_system/components/app_icon_button.dart';
import '../ui_system/perf/app_perf.dart';

class NotificationsScreen extends StatefulWidget {
  final String token;

  const NotificationsScreen({super.key, required this.token});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<AppNotification> _items;

  @override
  void initState() {
    super.initState();
    _items = NotificationService.all();
  }

  Future<void> _reload() async {
    setState(() => _items = NotificationService.all());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = theme.cardColor;
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.25 : 0.06);
    final reduceEffects = AppPerf.reduceEffects(context);
    final textMuted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
            (isDark ? AppColors.darkTextMuted : AppColors.textMuted);
    final sections = _buildSections(_items);
    final listItems = _buildListItems(sections);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Alertas'),
        actions: [
          AppIconButton(
            icon: IconsRounded.done_all,
            tooltip: 'Marcar todo',
            onPressed: _items.isEmpty ? null : _clearAllNotifications,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FadeSlideTransition(
          beginOffset: const Offset(0, 0.02),
          child: _items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    AppEmptyState(
                      icon: IconsRounded.notifications_off,
                      title: 'Sin alertas por ahora.',
                      subtitle: 'Te avisaremos si aparece algo nuevo.',
                      actionLabel: 'Actualizar',
                      onAction: () => _reload(),
                    ),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: listItems.length,
                  itemBuilder: (context, index) {
                    final item = listItems[index];
                    if (item.isHeader) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _sectionHeader(item.header!, textMuted),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _notificationTile(
                        item.item!,
                        cardColor,
                        shadowColor,
                        textMuted,
                        item.timeLabel!,
                        reduceEffects,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _notificationTile(
    AppNotification item,
    Color cardColor,
    Color shadowColor,
    Color textMuted,
    String timeLabel,
    bool reduceEffects,
  ) {
    final color = _kindColor(item.kind);
    final icon = _kindIcon(item.kind);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(IconsRounded.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        NotificationService.remove(item.id).then((_) {
          setState(() => _items = NotificationService.all());
        });
      },
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: reduceEffects
                ? const []
                : [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openNotificationDetail(item),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              timeLabel,
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          style: TextStyle(color: textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_NotificationSection> _buildSections(List<AppNotification> items) {
    final sorted = [...items]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(const Duration(days: 7));

    final todayItems = <AppNotification>[];
    final weekItems = <AppNotification>[];
    final olderItems = <AppNotification>[];

    for (final item in sorted) {
      final ts = item.timestamp;
      if (!ts.isBefore(todayStart)) {
        todayItems.add(item);
      } else if (!ts.isBefore(weekStart)) {
        weekItems.add(item);
      } else {
        olderItems.add(item);
      }
    }

    final sections = <_NotificationSection>[];
    if (todayItems.isNotEmpty) {
      sections.add(
        _NotificationSection(
          label: 'HOY',
          items: todayItems,
          timestampLabel: _formatTime,
        ),
      );
    }
    if (weekItems.isNotEmpty) {
      sections.add(
        _NotificationSection(
          label: 'ESTA SEMANA',
          items: weekItems,
          timestampLabel: _formatWeekday,
        ),
      );
    }
    if (olderItems.isNotEmpty) {
      sections.add(
        _NotificationSection(
          label: 'ANTERIORES',
          items: olderItems,
          timestampLabel: _formatShortDate,
        ),
      );
    }
    return sections;
  }

  List<_NotificationListItem> _buildListItems(
    List<_NotificationSection> sections,
  ) {
    final items = <_NotificationListItem>[];
    for (final section in sections) {
      items.add(_NotificationListItem.header(section.label));
      for (final item in section.items) {
        items.add(
          _NotificationListItem.item(
            item,
            section.timestampLabel(item.timestamp),
          ),
        );
      }
    }
    return items;
  }

  Widget _sectionHeader(String label, Color muted) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: muted,
      ),
    );
  }

  Future<void> _clearAllNotifications() async {
    await NotificationService.clear();
    if (!mounted) return;
    setState(() => _items = NotificationService.all());
  }

  void _openNotificationDetail(AppNotification item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textMuted = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final color = _kindColor(item.kind);
    final icon = _kindIcon(item.kind);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.of(sheetContext).viewInsets.bottom;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: textMuted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                  Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Detalle de alerta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                _detailRow('Tipo', _kindLabel(item.kind), textMuted),
                const SizedBox(height: 6),
                _detailRow('Fecha', _formatFullDate(item.timestamp), textMuted),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await NotificationService.remove(item.id);
                          if (!mounted) return;
                          setState(() => _items = NotificationService.all());
                          if (!sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                        },
                        icon: const Icon(IconsRounded.delete_outline),
                        label: const Text('Eliminar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade400,
                          side: BorderSide(color: Colors.red.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, Color textMuted) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: textMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Color _kindColor(NotificationKind kind) {
    return switch (kind) {
      NotificationKind.event => AppColors.info,
      NotificationKind.warning => AppColors.warning,
      NotificationKind.info => AppColors.success,
    };
  }

  IconData _kindIcon(NotificationKind kind) {
    return switch (kind) {
      NotificationKind.event => IconsRounded.event,
      NotificationKind.warning => IconsRounded.warning_rounded,
      NotificationKind.info => IconsRounded.notifications,
    };
  }

  String _kindLabel(NotificationKind kind) {
    return switch (kind) {
      NotificationKind.event => 'Evento',
      NotificationKind.warning => 'Alerta',
      NotificationKind.info => 'Aviso',
    };
  }

  String _formatTime(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}';
  }

  String _formatWeekday(DateTime time) {
    const labels = [
      'Lun',
      'Mar',
      'Mie',
      'Jue',
      'Vie',
      'Sab',
      'Dom',
    ];
    return labels[time.weekday - 1];
  }

  String _formatShortDate(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.day)}/${two(time.month)}';
  }

  String _formatFullDate(DateTime time) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.day)}/${two(time.month)}/${time.year} ${two(time.hour)}:${two(time.minute)}';
  }
}

class _NotificationSection {
  final String label;
  final List<AppNotification> items;
  final String Function(DateTime) timestampLabel;

  const _NotificationSection({
    required this.label,
    required this.items,
    required this.timestampLabel,
  });
}

class _NotificationListItem {
  final String? header;
  final AppNotification? item;
  final String? timeLabel;

  const _NotificationListItem.header(this.header)
      : item = null,
        timeLabel = null;

  const _NotificationListItem.item(this.item, this.timeLabel) : header = null;

  bool get isHeader => header != null;
}
