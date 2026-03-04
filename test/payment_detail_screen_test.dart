import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gestion_condominios/models/inmueble.dart';
import 'package:gestion_condominios/models/payment_report.dart';
import 'package:gestion_condominios/screens/payment_detail_screen.dart';
import 'package:gestion_condominios/theme/app_theme.dart';

void main() {
  testWidgets('Payment detail shows empty debt and reports states',
      (WidgetTester tester) async {
    final inmueble = Inmueble(
      idInmueble: '1',
      idCondominio: '1',
      idUsuario: '1',
      estado: EstadoInmueble.alDia,
      identificacion: 'A-1',
      nombreCondominio: 'Condominio Demo',
      pagos: const [],
    );

    Future<List<PaymentReport>> loader({
      required String token,
      String? idInmueble,
    }) async {
      return <PaymentReport>[];
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PaymentDetailScreen(
          inmueble: inmueble,
          totalDeuda: 0,
          token: 'token',
          reportesLoader: loader,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Estado de cuenta'), findsOneWidget);
    expect(find.text('No hay deuda pendiente.'), findsOneWidget);
    expect(find.text('Pagos reportados'), findsOneWidget);
    expect(find.text('No hay pagos reportados.'), findsOneWidget);
  });
}
