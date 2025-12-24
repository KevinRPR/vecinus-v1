import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/inmueble.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'notifications_screen.dart';
import 'payments_screen.dart';
import 'user_screen.dart';

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
  DateTime? _lastFetch;
  static const double _floatingNavHeight = 90;
  static const Duration _staleAfter = Duration(seconds: 30);
  static const _cacheInmueblesKey = 'cache_inmuebles';
  static const _cacheFetchKey = 'cache_inmuebles_fetched_at';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUser = widget.user;
    _pageController = PageController();
    _restoreCachedInmuebles().then((_) => _loadInmuebles());
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
    setState(() => _loadingData = _inmuebles.isEmpty);
    try {
      final data = await ApiService.getMisInmuebles(widget.token);
      if (!mounted) return;
      setState(() {
        _inmuebles = data;
        _loadingData = false;
        _lastFetch = DateTime.now();
      });
      await _persistCache(data, _lastFetch!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los inmuebles: $e')),
      );
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

  Future<void> _persistCache(List<Inmueble> items, DateTime fetchedAt) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        items.map((i) => i.toJson()).toList(growable: false);
    await prefs.setString(_cacheInmueblesKey, jsonEncode(encoded));
    await prefs.setString(_cacheFetchKey, fetchedAt.toIso8601String());
  }

  void _maybeRefreshData() {
    final now = DateTime.now();
    if (_lastFetch == null ||
        (!_loadingData && now.difference(_lastFetch!) > _staleAfter)) {
      _loadInmuebles();
    }
  }

  void _handleUserUpdated(User user) {
    setState(() => _currentUser = user);
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
    final navOverlapPadding = _floatingNavHeight + bottomInset + 16;
    final pages = [
      DashboardScreen(
        user: _currentUser,
        inmuebles: _inmuebles,
        loading: _loadingData,
        onRefresh: _loadInmuebles,
        onViewPayments: () => _onTabSelected(1),
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
    final items = [
      _NavItem(icon: Icons.home_rounded, label: 'Inicio'),
      _NavItem(icon: Icons.account_balance_wallet_outlined, label: 'Pagos'),
      _NavItem(icon: Icons.notifications_none_rounded, label: 'Alertas'),
      _NavItem(icon: Icons.person_outline, label: 'Perfil'),
    ];

    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        height: _floatingNavHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                        theme.brightness == Brightness.dark ? 0.4 : 0.07),
                    blurRadius: 24,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(items.length, (index) {
                  final selected = _currentIndex == index;
                  final item = items[index];

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onTabSelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding:
                                  selected ? const EdgeInsets.all(8) : const EdgeInsets.all(6),
                              decoration: selected
                                  ? const BoxDecoration(
                                      color: Color(0xff1d9bf0),
                                      shape: BoxShape.circle,
                                    )
                                  : null,
                              child: Icon(
                                item.icon,
                                color: selected
                                    ? Colors.white
                                    : onSurface.withOpacity(0.55),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: selected
                                    ? onSurface
                                    : onSurface.withOpacity(0.55),
                                fontWeight:
                                    selected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
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
