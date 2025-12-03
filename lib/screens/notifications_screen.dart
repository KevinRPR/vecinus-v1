import 'package:flutter/material.dart';

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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Alertas'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _items = _generateNotifications()),
          )
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemBuilder: (_, index) => _notificationTile(_items[index]),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: _items.length,
      ),
    );
  }

  Widget _notificationTile(_NotificationItem item) {
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatTimeAgo(item.timestamp),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
