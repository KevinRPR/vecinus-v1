import 'package:intl/intl.dart';

final NumberFormat _moneyFormat = NumberFormat('#,##0.00', 'es');

String formatMoney(
  num? value, {
  String symbol = r'$',
  bool withSymbol = true,
}) {
  if (value == null) return '--';
  final formatted = _moneyFormat.format(value);
  if (!withSymbol) return formatted;
  return '$symbol$formatted';
}

