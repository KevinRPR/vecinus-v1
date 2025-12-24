import 'package:flutter/material.dart';

import '../animations/transitions.dart';
import '../services/notification_service.dart';

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
            setState(() => _items = NotificationService.all()),
        child: FadeSlideTransition(
          beginOffset: const Offset(0, 0.02),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    'No tienes alertas.',
                    style: TextStyle(color: textMuted),
                  ),
                )
              else
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
    AppNotification item,
    Color cardColor,
    Color shadowColor,
    Color textMuted,
  ) {
    final color = switch (item.kind) {
      NotificationKind.event => const Color(0xff2563eb),
      NotificationKind.warning => const Color(0xfff97316),
      NotificationKind.info => const Color(0xff10b981),
    };
    final icon = switch (item.kind) {
      NotificationKind.event => Icons.event,
      NotificationKind.warning => Icons.warning_amber_rounded,
      NotificationKind.info => Icons.notifications_active_outlined,
    };

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        NotificationService.remove(item.id).then((_) {
          setState(() => _items = NotificationService.all());
        });
      },
      child: Container(
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
