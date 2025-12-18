import 'package:flutter/material.dart';

class AppNotification {
  final String id;
  final String title;
  final String subtitle;
  final NotificationKind kind;
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum NotificationKind { info, warning, event }

class NotificationService {
  static final List<AppNotification> _items = [];

  static List<AppNotification> all() => List.unmodifiable(_items);

  static void add({
    required String title,
    required String subtitle,
    NotificationKind kind = NotificationKind.info,
  }) {
    _items.insert(
      0,
      AppNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        subtitle: subtitle,
        kind: kind,
      ),
    );
  }

  static void remove(String id) {
    _items.removeWhere((n) => n.id == id);
  }

  static void clear() {
    _items.clear();
  }
}
