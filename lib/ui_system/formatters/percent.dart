import 'package:intl/intl.dart';

final NumberFormat _percentFormat = NumberFormat('#,##0.00', 'es');

String formatPercent(
  num? value, {
  bool includeSymbol = false,
  bool valueIsRatio = false,
}) {
  if (value == null) return '--';
  final normalized = valueIsRatio ? value * 100 : value;
  final formatted = _percentFormat.format(normalized);
  return includeSymbol ? '$formatted%' : formatted;
}

