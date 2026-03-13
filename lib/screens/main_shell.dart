import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/inmueble.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/payment_report_queue_service.dart';
import '../services/payment_report_status_sync_service.dart';
import '../preferences_controller.dart';
import '../animations/transitions.dart';
import '../theme/app_theme.dart';
import '../ui_system/perf/app_perf.dart';
import 'dashboard_screen.dart';
import 'notifications_screen.dart';
import 'payments_screen.dart';
import 'user_screen.dart';
import 'login_screen.dart';

class MainShell extends StatefulWidget {
  final User user;
  final String token;
  final bool fromQuickAccess;

  const MainShell({
    super.key,
    required this.user,
    required this.token,
    this.fromQuickAccess = false,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late User _currentUser;
  late final PageController _pageController;
  List<Inmueble> _inmuebles = [];
  bool _loadingData = true;
  bool _refreshing = false;
  bool _handlingAuthError = false;
  late String _token;
  DateTime? _lastFetch;
  static const double _floatingNavHeight = 72;
  static const bool _useCache = true;
  static const Duration _cacheTtl = Duration(minutes: 10);
  static const _cacheInmueblesKey = 'cache_inmuebles';
  static const _cacheFetchKey = 'cache_inmuebles_fetched_at';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUser = widget.user;
    _token = widget.token;
    _pageController = PageController();
    _syncToken();
    if (_useCache) {
      _restoreCachedInmuebles().then((shouldFetch) {
        if (shouldFetch) {
          _loadInmuebles();
        }
      });
    } else {
      _clearInmueblesCache();
      _loadInmuebles();
    }
    preferencesController.loadForUser(widget.user.id);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeRefreshData();
      unawaited(_syncReportServices(trigger: 'resume'));
    }
  }

  Future<void> _loadInmuebles() async {
    if (_refreshing) return;
    _refreshing = true;
    setState(() => _loadingData = _inmuebles.isEmpty);
    try {
      final storedToken = await AuthService.getToken();
      if (!mounted) return;
      if (storedToken == null || storedToken.isEmpty) {
        setState(() => _loadingData = false);
        await _handleAuthError();
        return;
      }
      if (storedToken != _token) {
        setState(() => _token = storedToken);
      }
      final data = await ApiService.getMisInmuebles(_token);
      if (!mounted) return;
      setState(() {
        _inmuebles = data;
        _loadingData = false;
        _lastFetch = DateTime.now();
      });
      if (_useCache) {
        await _persistCache(data, _lastFetch!);
      }
    } catch (e) {
      if (!mounted) return;
      if (_isAuthError(e)) {
        setState(() => _loadingData = false);
        await _handleAuthError();
        return;
      }
      if (widget.fromQuickAccess &&
          _inmuebles.isEmpty &&
          !_isConnectionError(e)) {
        final valid = await _validateSession();
        if (!mounted) return;
        if (!valid) {
          setState(() => _loadingData = false);
          await _handleAuthError();
          return;
        }
      }
      setState(() => _loadingData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los inmuebles: $e')),
      );
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _syncToken() async {
    final stored = await AuthService.getToken();
    if (!mounted) return;
    if (stored == null || stored.isEmpty) {
      await _handleAuthError();
      return;
    }
    if (stored != _token) {
      setState(() => _token = stored);
    }
  }

  Future<bool> _restoreCachedInmuebles() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getString(_cacheInmueblesKey);
    if (rawList == null || rawList.isEmpty) {
      return true;
    }
    final fetchedAt = DateTime.tryParse(prefs.getString(_cacheFetchKey) ?? '');
    if (fetchedAt == null) {
      await _clearInmueblesCache();
      return true;
    }
    if (DateTime.now().difference(fetchedAt) > _cacheTtl) {
      await _clearInmueblesCache();
      return true;
    }
    try {
      final List decoded = jsonDecode(rawList);
      final inmuebles =
          decoded.whereType<Map<String, dynamic>>().map(Inmueble.fromJson).toList();
      if (!mounted) return false;
      setState(() {
        _inmuebles = inmuebles;
        _lastFetch = fetchedAt;
        _loadingData = false;
      });
      return false;
    } catch (_) {
      // ignore cache errors
      return true;
    }
  }

  Future<void> _clearInmueblesCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheInmueblesKey);
    await prefs.remove(_cacheFetchKey);
    _lastFetch = null;
  }

  Future<void> _persistCache(List<Inmueble> items, DateTime fetchedAt) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        items.map((i) => i.toJson()).toList(growable: false);
    await prefs.setString(_cacheInmueblesKey, jsonEncode(encoded));
    await prefs.setString(_cacheFetchKey, fetchedAt.toIso8601String());
  }

  bool _isCacheFresh() {
    if (!_useCache) return false;
    if (_lastFetch == null) return false;
    return DateTime.now().difference(_lastFetch!) <= _cacheTtl;
  }

  bool _isAuthError(Object error) {
    if (error is ApiAuthException) return true;
    final message = error.toString().toLowerCase();
    return message.contains('token') || message.contains('401');
  }

  bool _isConnectionError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('conexion') ||
        message.contains('conexión') ||
        message.contains('timeout') ||
        message.contains('socket');
  }

  Future<bool> _validateSession() async {
    try {
      await ApiService.fetchProfile(_token);
      return true;
    } catch (e) {
      if (_isAuthError(e)) return false;
      return true;
    }
  }

  Future<void> _handleAuthError() async {
    if (_handlingAuthError) return;
    _handlingAuthError = true;
    await AuthService.logout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu sesión expiró. Inicia sesión nuevamente.'),
      ),
    );
    Navigator.of(context).pushAndRemoveUntil(
      fadeSlideRoute(const LoginScreen()),
      (route) => false,
    );
  }

  void _maybeRefreshData() {
    if (_isCacheFresh()) return;
    _loadInmuebles();
  }

  void _handleUserUpdated(User user) {
    setState(() => _currentUser = user);
    preferencesController.loadForUser(user.id);
  }

  void _onTabSelected(int index) {
    if (index == 0 || index == 1) {
      _maybeRefreshData();
    }
    if (index == 1) {
      unawaited(_syncReportServices(trigger: 'payments_tab'));
    }
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final navOverlapPadding = _floatingNavHeight + bottomInset;
    final pages = [
      DashboardScreen(
        user: _currentUser,
        inmuebles: _inmuebles,
        loading: _loadingData,
        onRefresh: _loadInmuebles,
        onViewPayments: () => _onTabSelected(1),
        onViewAlerts: () => _onTabSelected(2),
        onViewProfile: () => _onTabSelected(3),
        lastSync: _lastFetch,
      ),
      PaymentsScreen(
        inmuebles: _inmuebles,
        loading: _loadingData,
        onRefresh: _loadInmuebles,
        token: _token,
        lastSync: _lastFetch,
      ),
      NotificationsScreen(token: _token),
      UserScreen(
        user: _currentUser,
        token: _token,
        inmuebles: _inmuebles,
        embedded: true,
        onUserUpdated: _handleUserUpdated,
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: Padding(
        padding: EdgeInsets.only(bottom: navOverlapPadding),
        child: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (index) => setState(() => _currentIndex = index),
          children: pages,
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildBottomNavigation() {
    const items = [
      _NavItem(icon: IconsRounded.home, label: 'Inicio'),
      _NavItem(icon: IconsRounded.account_balance_wallet, label: 'Pagos'),
      _NavItem(icon: IconsRounded.notifications, label: 'Alertas'),
      _NavItem(icon: IconsRounded.person, label: 'Perfil'),
    ];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const primary = AppColors.brandBlue600;
    final muted = theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.65 : 0.55);
    final background =
        theme.colorScheme.surface.withValues(alpha: isDark ? 0.94 : 0.96);
    final borderColor = theme.colorScheme.outline.withValues(
      alpha: isDark ? 0.6 : 0.7,
    );
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final hasAlerts = NotificationService.all().isNotEmpty;
    final dotBorderColor = theme.colorScheme.surface;

    final blurSigma = AppPerf.blurSigma(context, 12);
    final navContent = Container(
      padding: EdgeInsets.fromLTRB(24, 10, 24, 10 + bottomInset),
      decoration: BoxDecoration(
        color: background,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(items.length, (index) {
          final selected = _currentIndex == index;
          final item = items[index];
          final iconColor = selected ? Colors.white : muted;
          final labelColor = selected ? primary : muted;

          return Expanded(
            child: Semantics(
              label: item.label,
              button: true,
              selected: selected,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  onTap: () => _onTabSelected(index),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: selected
                            ? BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              )
                            : null,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(item.icon, color: iconColor, size: 22),
                            if (index == 2 && hasAlerts)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: dotBorderColor,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: labelColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );

    return ClipRect(
      child: blurSigma == 0
          ? navContent
          : BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: navContent,
            ),
    );
  }

  Future<void> _syncReportServices({required String trigger}) async {
    if (_token.trim().isEmpty) return;
    await PaymentReportQueueService.flush(
      token: _token,
      trigger: trigger,
    );
    await PaymentReportStatusSyncService.sync(
      token: _token,
      trigger: trigger,
    );
    if (!mounted) return;
    setState(() {});
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
