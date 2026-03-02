String safeText(
  String? value, {
  String fallback = 'No disponible',
}) {
  if (value == null) return fallback;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return fallback;
  final lowered = trimmed.toLowerCase();
  if (lowered == 'null' || lowered == 'undefined' || lowered == 'nan') {
    return fallback;
  }
  return trimmed;
}

String safeTextOrEmpty(String? value) {
  return safeText(value, fallback: '');
}
