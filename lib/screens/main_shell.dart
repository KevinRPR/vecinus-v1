import 'package:flutter/material.dart';

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

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late User _currentUser;
  late final PageController _pageController;
  List<Inmueble> _inmuebles = [];
  bool _loadingData = true;
  static const double _floatingNavHeight = 90;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _pageController = PageController();
    _loadInmuebles();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInmuebles() async {
    setState(() => _loadingData = true);
    try {
      final data = await ApiService.getMisInmuebles(widget.token);
      if (!mounted) return;
      setState(() {
        _inmuebles = data;
        _loadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los inmuebles: $e')),
      );
    }
  }

  void _handleUserUpdated(User user) {
    setState(() => _currentUser = user);
  }

  void _onTabSelected(int index) {
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
      ),
      PaymentsScreen(
        inmuebles: _inmuebles,
        loading: _loadingData,
        onRefresh: _loadInmuebles,
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
                                  ? BoxDecoration(
                                      color: const Color(0xff1d9bf0),
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
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
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
