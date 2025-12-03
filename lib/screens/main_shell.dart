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
      backgroundColor: const Color(0xfff7f4fb),
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: pages,
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

    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 12, left: 16, right: 16, top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final selected = _currentIndex == index;
            final item = items[index];
            final bool centralHighlight = index == 2;

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onTabSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: centralHighlight && selected
                            ? const EdgeInsets.all(9)
                            : const EdgeInsets.all(7),
                        decoration: selected
                            ? BoxDecoration(
                                color: centralHighlight
                                    ? const Color(0xff1d9bf0)
                                    : const Color(0xffe8efff),
                                shape: centralHighlight
                                    ? BoxShape.circle
                                    : BoxShape.rectangle,
                                borderRadius: centralHighlight
                                    ? null
                                    : BorderRadius.circular(18),
                              )
                            : null,
                        child: Icon(
                          item.icon,
                          color: selected
                              ? (centralHighlight
                                  ? Colors.white
                                  : const Color(0xff1d9bf0))
                              : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: selected
                              ? const Color(0xff1f2933)
                              : Colors.grey.shade500,
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
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}
