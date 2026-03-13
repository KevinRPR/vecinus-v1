import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'notification_service.dart';
import 'observability_service.dart';

class PendingPaymentReport {
  final String clientUuid;
  final String inmuebleId;
  final String fechaPago;
  final String? observacion;
  final List<Map<String, dynamic>> notificaciones;
  final List<Map<String, dynamic>> pagos;
  final String? comprobanteBase64;
  final String? comprobanteExt;
  final DateTime queuedAt;
  final DateTime? nextAttemptAt;
  final int attempts;
  final String? lastError;
  final bool blocked;

  const PendingPaymentReport({
    required this.clientUuid,
    required this.inmuebleId,
    required this.fechaPago,
    required this.notificaciones,
    required this.pagos,
    this.observacion,
    this.comprobanteBase64,
    this.comprobanteExt,
    required this.queuedAt,
    this.nextAttemptAt,
    this.attempts = 0,
    this.lastError,
    this.blocked = false,
  });

  factory PendingPaymentReport.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> parseList(dynamic raw) {
      if (raw is! List) return const <Map<String, dynamic>>[];
      return raw.whereType<Map<String, dynamic>>().toList();
    }

    return PendingPaymentReport(
      clientUuid: (json['client_uuid'] ?? '').toString(),
      inmuebleId: (json['inmueble_id'] ?? '').toString(),
      fechaPago: (json['fecha_pago'] ?? '').toString(),
      observacion: json['observacion']?.toString(),
      notificaciones: parseList(json['notificaciones']),
      pagos: parseList(json['pagos']),
      comprobanteBase64: json['comprobante_base64']?.toString(),
      comprobanteExt: json['comprobante_ext']?.toString(),
      queuedAt:
          DateTime.tryParse((json['queued_at'] ?? '').toString()) ?? DateTime.now(),
      nextAttemptAt: DateTime.tryParse((json['next_attempt_at'] ?? '').toString()),
      attempts: int.tryParse((json['attempts'] ?? '').toString()) ?? 0,
      lastError: json['last_error']?.toString(),
      blocked: json['blocked'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_uuid': clientUuid,
      'inmueble_id': inmuebleId,
      'fecha_pago': fechaPago,
      'observacion': observacion,
      'notificaciones': notificaciones,
      'pagos': pagos,
      'comprobante_base64': comprobanteBase64,
      'comprobante_ext': comprobanteExt,
      'queued_at': queuedAt.toIso8601String(),
      'next_attempt_at': nextAttemptAt?.toIso8601String(),
      'attempts': attempts,
      'last_error': lastError,
      'blocked': blocked,
    };
  }

  PendingPaymentReport copyWith({
    DateTime? nextAttemptAt,
    int? attempts,
    String? lastError,
    bool? blocked,
  }) {
    return PendingPaymentReport(
      clientUuid: clientUuid,
      inmuebleId: inmuebleId,
      fechaPago: fechaPago,
      observacion: observacion,
      notificaciones: notificaciones,
      pagos: pagos,
      comprobanteBase64: comprobanteBase64,
      comprobanteExt: comprobanteExt,
      queuedAt: queuedAt,
      nextAttemptAt: nextAttemptAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError,
      blocked: blocked ?? this.blocked,
    );
  }
}

class QueueFlushResult {
  final int processed;
  final int success;
  final int failed;
  final int remaining;

  const QueueFlushResult({
    required this.processed,
    required this.success,
    required this.failed,
    required this.remaining,
  });
}

class PaymentReportQueueService {
  static const String _prefsKey = 'pending_payment_reports_v1';
  static const int _maxAttempts = 6;

  const PaymentReportQueueService._();

  static Future<List<PendingPaymentReport>> all() async {
    final rows = await _read();
    rows.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
    return rows;
  }

  static Future<List<PendingPaymentReport>> byInmueble(String inmuebleId) async {
    final rows = await all();
    return rows.where((item) => item.inmuebleId == inmuebleId).toList();
  }

  static Future<void> enqueue(PendingPaymentReport item) async {
    final rows = await _read();
    final next = <PendingPaymentReport>[
      ...rows.where((row) => row.clientUuid != item.clientUuid),
      item,
    ];
    await _write(next);
    await ObservabilityService.logEvent(
      'payment_queue_enqueued',
      data: {
        'client_uuid': item.clientUuid,
        'inmueble_id': item.inmuebleId,
      },
    );
  }

  static Future<void> remove(String clientUuid) async {
    final rows = await _read();
    await _write(rows.where((item) => item.clientUuid != clientUuid).toList());
  }

  static Future<QueueFlushResult> flush({
    required String token,
    String trigger = 'manual',
  }) async {
    final rows = await all();
    var processed = 0;
    var success = 0;
    var failed = 0;
    final now = DateTime.now();
    final next = <PendingPaymentReport>[];

    for (final item in rows) {
      if (item.blocked || item.attempts >= _maxAttempts) {
        next.add(item);
        continue;
      }
      if (item.nextAttemptAt != null && item.nextAttemptAt!.isAfter(now)) {
        next.add(item);
        continue;
      }

      processed += 1;
      final result = await _sendOne(token: token, item: item, manual: false);
      if (result.sent) {
        success += 1;
        continue;
      }
      failed += 1;
      next.add(result.updatedItem ?? item);
    }

    await _write(next);
    await ObservabilityService.logEvent(
      'payment_queue_flush',
      data: {
        'trigger': trigger,
        'processed': processed,
        'success': success,
        'failed': failed,
        'remaining': next.length,
      },
    );
    return QueueFlushResult(
      processed: processed,
      success: success,
      failed: failed,
      remaining: next.length,
    );
  }

  static Future<bool> retryNow({
    required String token,
    required String clientUuid,
  }) async {
    final rows = await all();
    final index = rows.indexWhere((row) => row.clientUuid == clientUuid);
    if (index < 0) return false;

    final item = rows[index];
    final result = await _sendOne(token: token, item: item, manual: true);
    if (result.sent) {
      rows.removeAt(index);
      await _write(rows);
      return true;
    }

    rows[index] = result.updatedItem ?? item;
    await _write(rows);
    return false;
  }

  static bool isConnectivityFailure(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('no hay conexion') ||
        text.contains('no hay conexión') ||
        text.contains('timeout') ||
        text.contains('socket') ||
        text.contains('conexion segura') ||
        text.contains('conexión segura') ||
        text.contains('handshake');
  }

  static Future<_SendResult> _sendOne({
    required String token,
    required PendingPaymentReport item,
    required bool manual,
  }) async {
    try {
      final res = await ApiService.enviarPagoReporte(
        token: token,
        inmuebleId: item.inmuebleId,
        fechaPago: item.fechaPago,
        observacion: item.observacion,
        notificaciones: item.notificaciones,
        pagos: item.pagos,
        clientUuid: item.clientUuid,
        comprobanteBase64: item.comprobanteBase64,
        comprobanteExt: item.comprobanteExt,
      );

      final duplicate = res['duplicado'] == true;
      await NotificationService.add(
        title: duplicate
            ? 'Reporte en cola confirmado'
            : 'Reporte en cola enviado',
        subtitle: duplicate
            ? 'El reporte ${_shortClientUuid(item.clientUuid)} ya estaba procesado.'
            : 'Se envio correctamente ${_shortClientUuid(item.clientUuid)}.',
        kind: NotificationKind.info,
        eventKey: 'queue_sent_${item.clientUuid}',
        uniqueByEventKey: true,
      );
      return const _SendResult(sent: true);
    } catch (e, st) {
      final connectivity = isConnectivityFailure(e);
      final newAttempts = item.attempts + 1;
      final blockedByMax = !manual && newAttempts >= _maxAttempts;
      final blockedByBusiness = !connectivity;
      final blocked = blockedByMax || blockedByBusiness;
      final nextAttempt = blocked
          ? null
          : DateTime.now().add(_backoffFor(newAttempts));
      final updated = item.copyWith(
        attempts: newAttempts,
        nextAttemptAt: nextAttempt,
        blocked: blocked,
        lastError: e.toString(),
      );

      await ObservabilityService.captureException(
        e,
        stackTrace: st,
        context: 'payment_queue_send_failed',
        data: {
          'client_uuid': item.clientUuid,
          'manual': manual,
          'connectivity': connectivity,
          'attempts': newAttempts,
          'blocked': blocked,
        },
      );

      return _SendResult(sent: false, updatedItem: updated);
    }
  }

  static Duration _backoffFor(int attempt) {
    final safeAttempt = attempt < 1 ? 1 : attempt;
    final seconds = (15 * (1 << (safeAttempt - 1))).clamp(15, 15 * 60);
    return Duration(seconds: seconds);
  }

  static String _shortClientUuid(String uuid) {
    if (uuid.length <= 8) return '#$uuid';
    return '#${uuid.substring(0, 8)}';
  }

  static Future<List<PendingPaymentReport>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <PendingPaymentReport>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <PendingPaymentReport>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PendingPaymentReport.fromJson)
          .where((item) => item.clientUuid.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return <PendingPaymentReport>[];
    }
  }

  static Future<void> _write(List<PendingPaymentReport> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}

class _SendResult {
  final bool sent;
  final PendingPaymentReport? updatedItem;

  const _SendResult({
    required this.sent,
    this.updatedItem,
  });
}
