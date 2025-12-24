import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      kind: NotificationKind.values[json['kind'] as int],
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'kind': kind.index,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

enum NotificationKind { info, warning, event }

class NotificationService {
  static const _prefsKey = 'app_notifications';
  static final List<AppNotification> _items = [];
  static SharedPreferences? _prefs;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      final List<dynamic> list = jsonDecode(raw);
      _items
        ..clear()
        ..addAll(
          list
              .whereType<Map<String, dynamic>>()
              .map(AppNotification.fromJson)
              .toList(),
        );
    }
    _initialized = true;
  }

  static List<AppNotification> all() => List.unmodifiable(_items);

  static Future<void> add({
    required String title,
    required String subtitle,
    NotificationKind kind = NotificationKind.info,
  }) async {
    _items.insert(
      0,
      AppNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        subtitle: subtitle,
        kind: kind,
      ),
    );
    await _persist();
  }

  static Future<void> remove(String id) async {
    _items.removeWhere((n) => n.id == id);
    await _persist();
  }

  static Future<void> clear() async {
    _items.clear();
    await _persist();
  }

  static Future<void> _persist() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_items.map((n) => n.toJson()).toList()),
    );
  }
}
