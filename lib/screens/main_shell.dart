import 'dart:ui';

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

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNavigation(
        theme: theme,
        primary: primary,
        textColor: textColor,
        bottomInset: bottomInset,
      ),
    );
  }

  Widget _buildBottomNavigation({
    required ThemeData theme,
    required Color primary,
    required Color textColor,
    required double bottomInset,
  }) {
    final items = [
      _NavItem(icon: Icons.home_rounded, label: 'Inicio'),
      _NavItem(icon: Icons.account_balance_wallet_outlined, label: 'Pagos'),
      _NavItem(icon: Icons.notifications_none_rounded, label: 'Alertas'),
      _NavItem(icon: Icons.person_outline, label: 'Perfil'),
    ];

    final isDark = theme.brightness == Brightness.dark;
    final Color glassColor =
        isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.85);
    final Color borderColor = Colors.white.withOpacity(isDark ? 0.08 : 0.3);
    final double extraBottom = bottomInset > 0 ? bottomInset : 12;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, extraBottom),
        child: SizedBox(
          height: 86,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(34),
                        color: glassColor,
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withOpacity(isDark ? 0.45 : 0.18),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: List.generate(items.length, (index) {
                  final selected = _currentIndex == index;
                  final item = items[index];
                  final bool centralHighlight = index == 2;

                  final Color selectedColor =
                      centralHighlight ? Colors.white : primary;
                  final Color unselectedColor = textColor.withOpacity(0.5);

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onTabSelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.all(9),
                              decoration: selected
                                  ? BoxDecoration(
                                      color: centralHighlight
                                          ? primary
                                          : primary.withOpacity(
                                              isDark ? 0.22 : 0.18),
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
                                color:
                                    selected ? selectedColor : unselectedColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: selected
                                    ? textColor.withOpacity(0.9)
                                    : unselectedColor,
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
            ],
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
