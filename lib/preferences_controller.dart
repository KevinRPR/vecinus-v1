import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/user_preferences.dart';

class PreferencesController {
  PreferencesController._internal();

  static final PreferencesController _instance =
      PreferencesController._internal();

  factory PreferencesController() => _instance;

  static const String _storagePrefix = 'user_preferences_';
  final ValueNotifier<UserPreferences> preferences =
      ValueNotifier<UserPreferences>(UserPreferences.defaults());
  String? _currentUserId;

  Future<void> loadForUser(String userId) async {
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_storagePrefix$userId');
    if (raw == null || raw.isEmpty) {
      preferences.value = UserPreferences.defaults();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        preferences.value = UserPreferences.fromJson(decoded);
      } else {
        preferences.value = UserPreferences.defaults();
      }
    } catch (_) {
      preferences.value = UserPreferences.defaults();
    }
  }

  Future<void> update(UserPreferences updated) async {
    preferences.value = updated;
    await _persist();
  }

  Future<void> updateWith(
    UserPreferences Function(UserPreferences current) updater,
  ) async {
    await update(updater(preferences.value));
  }

  Future<void> reset() async {
    _currentUserId = null;
    preferences.value = UserPreferences.defaults();
  }

  Future<void> _persist() async {
    if (_currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_storagePrefix$_currentUserId',
      jsonEncode(preferences.value.toJson()),
    );
  }
}

final preferencesController = PreferencesController();
