import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import '../widgets/fade_slide_transition.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    _scheduleNavigation();
  }

  Future<void> _scheduleNavigation() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    await _checkSession();
  }

  Future<void> _checkSession() async {
    final token = await AuthService.getToken();
    final userMap = await AuthService.getUser();

    if (!mounted) return;

    if (token != null && userMap != null) {
      final user = User.fromJson(userMap);
      if (user.hasValidSession) {
        Navigator.of(context).pushReplacement(
          FadeSlidePageRoute(page: MainShell(user: user, token: token)),
        );
        return;
      } else {
        await AuthService.logout();
      }
    }

    Navigator.of(context).pushReplacement(
      FadeSlidePageRoute(page: const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);
          final colors = [
            const Color(0xff1d9bf0),
            const Color(0xff0a0f1f),
            const Color(0xffeff2ff),
          ];

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(colors[0], colors[2], t)!,
                  Color.lerp(colors[1], colors[0], t)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0.1, 0.9, curve: Curves.easeOut),
                    ),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _controller,
                          curve: Curves.fastLinearToSlowEaseIn,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/logo_3x.png',
                            height: 96,
                            filterQuality: FilterQuality.high,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Vecinus App',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.35,
                      child: Lottie.asset(
                        'assets/lottie/particles.json',
                        fit: BoxFit.cover,
                        repeat: true,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _WavePainter(progress: t),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;

  _WavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withOpacity(0.15);

    final path = Path();
    final amplitude = 18.0;
    final frequency = 1.5;

    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.65 +
          sin((x / size.width * 2 * pi * frequency) + progress * 2 * pi) *
              amplitude;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
