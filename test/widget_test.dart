// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gestion_condominios/screens/login_screen.dart';
import 'package:gestion_condominios/theme/app_theme.dart';

void main() {
  testWidgets('Login renders brand content', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final view = tester.view;
    view.physicalSize = const Size(1080, 1920);
    view.devicePixelRatio = 1.0;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const LoginScreen(),
      ),
    );

    expect(find.text('vecinus'), findsOneWidget);
  });
}
