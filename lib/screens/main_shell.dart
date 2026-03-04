import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/inmueble.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
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

  const MainShell({super.key, required this.user, required this.token});

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
    _pageController = PageController();
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
    }
  }

  Future<void> _loadInmuebles() async {
    if (_refreshing) return;
    _refreshing = true;
    setState(() => _loadingData = _inmuebles.isEmpty);
    try {
      final data = await ApiService.getMisInmuebles(widget.token);
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
      setState(() => _loadingData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los inmuebles: $e')),
      );
    } finally {
      _refreshing = false;
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

  Future<void> _handleAuthError() async {
    if (_handlingAuthError) return;
    _handlingAuthError = true;
    await AuthService.logout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tu sesion expiro. Inicia sesion nuevamente.')),
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
        lastSync: _lastFetch,
      ),
      PaymentsScreen(
        inmuebles: _inmuebles,
        loading: _loadingData,
        onRefresh: _loadInmuebles,
        token: widget.token,
        lastSync: _lastFetch,
      ),
      NotificationsScreen(token: widget.token),
      UserScreen(
        user: _currentUser,
        token: widget.token,
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
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
