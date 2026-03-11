import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gestion_condominios/models/inmueble.dart';
import 'package:gestion_condominios/screens/report_payment_screen.dart';
import 'package:gestion_condominios/theme/app_theme.dart';

void main() {
  testWidgets('Report payment shows no debt state when pending is empty',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final inmueble = Inmueble(
      idInmueble: '1',
      idCondominio: '1',
      idUsuario: '1',
      estado: EstadoInmueble.alDia,
      identificacion: 'A-1',
      nombreCondominio: 'Condominio Demo',
      pagos: const [],
    );

    Future<Map<String, dynamic>> loader({
      required String token,
      required String inmuebleId,
    }) async {
      return {
        'cuentas': <Map<String, dynamic>>[],
        'pendientes': <Map<String, dynamic>>[],
      };
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ReportPaymentScreen(
          token: 'token',
          inmueble: inmueble,
          prepareLoader: loader,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(
      find.text('No hay deuda pendiente en este inmueble.'),
      findsOneWidget,
    );
  });
}
