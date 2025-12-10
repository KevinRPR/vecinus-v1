import 'package:flutter/material.dart';

import '../animations/stagger_list.dart';
import '../animations/transitions.dart';

class NotificationsScreen extends StatefulWidget {
  final String token;

  const NotificationsScreen({super.key, required this.token});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<_NotificationItem> _items;

  @override
  void initState() {
    super.initState();
    _items = _generateNotifications();
  }

  List<_NotificationItem> _generateNotifications() {
    return [
      _NotificationItem(
        title: 'Reunión de condominio',
        subtitle: 'Sábado 10:00 AM • Salón A',
        type: NotificationType.event,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      _NotificationItem(
        title: 'Pago pendiente',
        subtitle: 'Apartamento Torre A • vence el 12 Feb',
        type: NotificationType.warning,
        timestamp: DateTime.now().subtract(const Duration(hours: 20)),
      ),
      _NotificationItem(
        title: 'Nuevo anuncio',
        subtitle: 'Se realizará mantenimiento a los ascensores',
        type: NotificationType.info,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? theme.cardColor : const Color(0xfff0f1f6);
    final shadowColor = Colors.black.withOpacity(isDark ? 0.25 : 0.06);
    final textMuted = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Alertas'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            setState(() => _items = _generateNotifications()),
        child: FadeSlideTransition(
          beginOffset: const Offset(0, 0.02),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              for (int i = 0; i < _items.length; i++) ...[
                _notificationTile(
                  _items[i],
                  cardColor,
                  shadowColor,
                  textMuted,
                ),
                if (i != _items.length - 1) const SizedBox(height: 12),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationTile(
    _NotificationItem item,
    Color cardColor,
    Color shadowColor,
    Color textMuted,
  ) {
    final color = switch (item.type) {
      NotificationType.event => const Color(0xff2563eb),
      NotificationType.warning => const Color(0xfff97316),
      NotificationType.info => const Color(0xff10b981),
    };
    final icon = switch (item.type) {
      NotificationType.event => Icons.event,
      NotificationType.warning => Icons.warning_amber_rounded,
      NotificationType.info => Icons.notifications_active_outlined,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: TextStyle(color: textMuted),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatTimeAgo(item.timestamp),
                  style: TextStyle(color: textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }
}

class _NotificationItem {
  final String title;
  final String subtitle;
  final NotificationType type;
  final DateTime timestamp;

  _NotificationItem({
    required this.title,
    required this.subtitle,
    required this.type,
    required this.timestamp,
  });
}

enum NotificationType { event, warning, info }
