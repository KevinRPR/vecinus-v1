import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/payment_report.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'observability_service.dart';

class PaymentReportStatusSyncService {
  static const String _snapshotKey = 'payment_report_status_snapshot_v1';
  static const bool _notifyFirstInReview = false;

  const PaymentReportStatusSyncService._();

  static Future<void> sync({
    required String token,
    List<PaymentReport>? reports,
    String trigger = 'manual',
  }) async {
    try {
      final items = reports ?? await ApiService.getMisPagosReportados(token: token);
      final previous = await _readSnapshot();
      final next = <String, String>{};

      for (final report in items) {
        final fingerprint = _fingerprint(report);
        next[report.id] = fingerprint;
        final oldFingerprint = previous[report.id];

        final changed = oldFingerprint != null && oldFingerprint != fingerprint;
        final firstSeen = oldFingerprint == null;
        if (!changed && !(firstSeen && _notifyFirstInReview && _isInReview(report))) {
          continue;
        }
        await _emitStatusNotification(report, fingerprint);
      }

      await _writeSnapshot(next);
      await ObservabilityService.logEvent(
        'report_status_sync_ok',
        data: {
          'trigger': trigger,
          'fetched': items.length,
        },
      );
    } catch (e, st) {
      await ObservabilityService.captureException(
        e,
        stackTrace: st,
        context: 'report_status_sync_failed',
        data: {'trigger': trigger},
      );
    }
  }

  static bool _isInReview(PaymentReport report) {
    final estado = report.estado.toUpperCase();
    return estado.contains('EN_PROCESO') || estado.contains('PROCESO');
  }

  static Future<Map<String, String>> _readSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_snapshotKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, String>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <String, String>{};
      final data = <String, String>{};
      for (final entry in decoded.entries) {
        final key = entry.key.trim();
        final value = entry.value?.toString().trim() ?? '';
        if (key.isEmpty || value.isEmpty) continue;
        data[key] = value;
      }
      return data;
    } catch (_) {
      return <String, String>{};
    }
  }

  static Future<void> _writeSnapshot(Map<String, String> snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snapshotKey, jsonEncode(snapshot));
  }

  static String _fingerprint(PaymentReport report) {
    final estado = report.estado.toUpperCase();
    final comentario = (report.comentarioAdmin ?? report.motivoRechazo ?? '').trim();
    final fechaEstado = _statusDate(report)?.toIso8601String() ?? '';
    final comentarioHash = _stableHash(comentario);
    return '${report.id}|$estado|$fechaEstado|$comentarioHash';
  }

  static DateTime? _statusDate(PaymentReport report) {
    final estado = report.estado.toUpperCase();
    if (estado == 'APROBADO') return report.aprobadoAt ?? report.createdAt;
    if (estado == 'RECHAZADO') return report.rechazadoAt ?? report.createdAt;
    return report.createdAt;
  }

  static int _stableHash(String value) {
    var hash = 2166136261;
    final bytes = utf8.encode(value);
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  static Future<void> _emitStatusNotification(
    PaymentReport report,
    String fingerprint,
  ) async {
    final estado = report.estado.toUpperCase();
    final comentario = (report.comentarioAdmin ?? report.motivoRechazo ?? '').trim();
    final numero = '#${report.id}';

    String title;
    String subtitle;
    NotificationKind kind;
    if (estado == 'APROBADO') {
      title = 'Tu reporte $numero fue aprobado';
      subtitle = comentario.isNotEmpty
          ? comentario
          : 'La administracion confirmo tu reporte.';
      kind = NotificationKind.event;
    } else if (estado == 'RECHAZADO') {
      title = 'Tu reporte $numero fue rechazado';
      subtitle = comentario.isNotEmpty
          ? comentario
          : 'Revisa el detalle y vuelve a reportar si aplica.';
      kind = NotificationKind.warning;
    } else {
      title = 'Tu reporte $numero esta en revision';
      subtitle = 'Te avisaremos cuando cambie de estado.';
      kind = NotificationKind.info;
    }

    await NotificationService.add(
      title: title,
      subtitle: subtitle,
      kind: kind,
      eventKey: 'report_status_$fingerprint',
      uniqueByEventKey: true,
    );
  }
}
