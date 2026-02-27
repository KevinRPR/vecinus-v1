import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/inmueble.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../preferences_controller.dart';
import 'dashboard_screen.dart';
import 'notifications_screen.dart';
import 'payments_screen.dart';
import 'user_screen.dart';

const _navPrimary = Color(0xff548C8C);
const _navBackgroundLight = Color(0xCCFFFFFF);
const _navBackgroundDark = Color(0xCC0F172A);
const _navBorderLight = Color(0xffE2E8F0);
const _navBorderDark = Color(0xff1F2937);
const _navMutedLight = Color(0xff94A3B8);
const _navMutedDark = Color(0xff64748B);

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
  DateTime? _lastFetch;
  static const double _floatingNavHeight = 72;
  static const bool _useCache = false;
  static const _cacheInmueblesKey = 'cache_inmuebles';
  static const _cacheFetchKey = 'cache_inmuebles_fetched_at';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUser = widget.user;
    _pageController = PageController();
    if (_useCache) {
      _restoreCachedInmuebles().then((_) => _loadInmuebles());
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
      setState(() => _loadingData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los inmuebles: $e')),
      );
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _restoreCachedInmuebles() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getString(_cacheInmueblesKey);
    if (rawList != null) {
      try {
        final List decoded = jsonDecode(rawList);
        final inmuebles =
            decoded.whereType<Map<String, dynamic>>().map(Inmueble.fromJson).toList();
        final fetchedAt = DateTime.tryParse(prefs.getString(_cacheFetchKey) ?? '');
        if (!mounted) return;
        setState(() {
          _inmuebles = inmuebles;
          _lastFetch = fetchedAt;
          _loadingData = false;
        });
      } catch (_) {
        // ignore cache errors
      }
    }
  }

  Future<void> _clearInmueblesCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheInmueblesKey);
    await prefs.remove(_cacheFetchKey);
  }

  Future<void> _persistCache(List<Inmueble> items, DateTime fetchedAt) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        items.map((i) => i.toJson()).toList(growable: false);
    await prefs.setString(_cacheInmueblesKey, jsonEncode(encoded));
    await prefs.setString(_cacheFetchKey, fetchedAt.toIso8601String());
  }

  void _maybeRefreshData() {
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
      _NavItem(icon: Icons.home_rounded, label: 'Inicio'),
      _NavItem(icon: Icons.account_balance_wallet_outlined, label: 'Pagos'),
      _NavItem(icon: Icons.notifications_none_rounded, label: 'Alertas'),
      _NavItem(icon: Icons.person_outline, label: 'Perfil'),
    ];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? _navMutedDark : _navMutedLight;
    final background = isDark ? _navBackgroundDark : _navBackgroundLight;
    final borderColor = isDark ? _navBorderDark : _navBorderLight;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final hasAlerts = NotificationService.all().isNotEmpty;
    final dotBorderColor = isDark ? _navBorderDark : Colors.white;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
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
              final labelColor = selected ? _navPrimary : muted;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTabSelected(index),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: selected
                            ? BoxDecoration(
                                color: _navPrimary,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: _navPrimary.withValues(alpha: 0.3),
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
                                    color: const Color(0xffEF4444),
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
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
