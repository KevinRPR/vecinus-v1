import 'package:flutter/material.dart';

import '../animations/transitions.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../preferences_controller.dart';
import 'unlock_screen.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import '../theme/app_theme.dart';

const _logoAsset = 'lib/assets/vecinus iso-01.png';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _shimmerController;
  late final AnimationController _fadeController;
  late final Animation<double> _floatAnimation;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentOffset;
  late final Animation<double> _bottomOpacity;
  late final Animation<Offset> _bottomOffset;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _floatAnimation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _contentOpacity = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _contentOffset = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _bottomOpacity = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _bottomOffset = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final token = await AuthService.getToken();
    final userMap = await AuthService.getUser();

    if (!mounted) return;

    if (token != null && token.trim().isNotEmpty && userMap != null) {
      var hasValidSession = await AuthService.isLoggedIn();
      if (!hasValidSession) {
        final refreshed = await AuthService.tryRefreshSession();
        if (refreshed) {
          hasValidSession = await AuthService.isLoggedIn();
        }
      }
      if (!hasValidSession) {
        await AuthService.logout();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          fadeSlideRoute(const LoginScreen()),
        );
        return;
      }
      final user = User.fromJson(userMap);

      await preferencesController.loadForUser(user.id);
      if (!mounted) return;
      final security = preferencesController.preferences.value.security;
      if (security.biometricForLogin || security.pinForLogin) {
        Navigator.pushReplacement(
          context,
          fadeSlideRoute(
            UnlockScreen(
              user: user,
              token: token,
              security: security,
            ),
          ),
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        fadeSlideRoute(MainShell(user: user, token: token)),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      fadeSlideRoute(const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _shimmerController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = theme.scaffoldBackgroundColor;
    final muted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
            (isDark ? AppColors.darkTextMuted : AppColors.textMuted);
    final titleColor =
        isDark ? theme.colorScheme.onSurface : AppColors.brandTeal600;
    final progressTrack =
        isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: FadeTransition(
                  opacity: _contentOpacity,
                  child: SlideTransition(
                    position: _contentOffset,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _floatAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _floatAnimation.value),
                              child: child,
                            );
                          },
                          child: SizedBox(
                            width: 128,
                            height: 128,
                            child: Center(
                              child: Image.asset(
                                _logoAsset,
                                height: 92,
                                width: 92,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    IconsRounded.home_work,
                                    size: 72,
                                    color: titleColor,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'vecinus',
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Tu condominio, claro y en orden.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: muted,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FadeTransition(
                opacity: _bottomOpacity,
                child: SlideTransition(
                  position: _bottomOffset,
                  child: Column(
                    children: [
                      Text(
                        'PREPARANDO TU ESPACIO...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: muted.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 6,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(color: progressTrack),
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: 0.65,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(color: AppColors.brandBlue600),
                                    AnimatedBuilder(
                                      animation: _shimmerController,
                                      builder: (context, child) {
                                        final shimmer =
                                            _shimmerController.value;
                                        return DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.white.withValues(alpha: 0),
                                                Colors.white.withValues(alpha: 0.45),
                                                Colors.white.withValues(alpha: 0),
                                              ],
                                              stops: const [0, 0.5, 1],
                                              begin: Alignment(
                                                -1 + (2 * shimmer),
                                                0,
                                              ),
                                              end: Alignment(
                                                1 + (2 * shimmer),
                                                0,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            IconsRounded.verified_user,
                            size: 18,
                            color: AppColors.brandBlue600.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'SMART GUARDIAN ACTIVE',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    AppColors.brandBlue600.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
