import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/inmueble.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/observability_service.dart';
import '../theme/app_theme.dart';
import '../ui_system/components/app_empty_state.dart';
import '../ui_system/components/app_icon_button.dart';
import '../ui_system/feedback/app_haptics.dart';
import '../ui_system/formatters/money.dart';
import '../ui_system/perf/app_perf.dart';

typedef PreparePagoReporteLoader = Future<Map<String, dynamic>> Function({
  required String token,
  required String inmuebleId,
});

enum _ReportStep { amount, selectBank, bankDetails, form, success }

class ReportPaymentScreen extends StatefulWidget {
  final String token;
  final Inmueble inmueble;
  final PreparePagoReporteLoader? prepareLoader;

  const ReportPaymentScreen({
    super.key,
    required this.token,
    required this.inmueble,
    this.prepareLoader,
  });

  @override
  State<ReportPaymentScreen> createState() => _ReportPaymentScreenState();
}

class _ReportPaymentScreenState extends State<ReportPaymentScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  int? _selectedAccount;
  _ReportStep _step = _ReportStep.amount;
  late final String _clientUuid;
  bool _payFull = true;

  final TextEditingController _obsCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _montoUsdCtrl = TextEditingController();
  DateTime _fechaPago = DateTime.now();

  final _picker = ImagePicker();
  String? _evidenceBase64;
  String? _evidenceExt;
  String? _evidenceName;
  int? _evidenceBytes;
  String? _formError;

  static const int _maxEvidenceBytes = 2 * 1024 * 1024;
  static const List<String> _allowedEvidenceExt = ['jpg', 'jpeg', 'png'];

  @override
  void initState() {
    super.initState();
    _clientUuid = ApiService.generateClientUuid();
    _load();
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    _refCtrl.dispose();
    _montoUsdCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loader = widget.prepareLoader ?? ApiService.preparePagoReporte;
      final res = await loader(
        token: widget.token,
        inmuebleId: widget.inmueble.idInmueble,
      );
      setState(() {
        _data = res;
        _loading = false;
        if (_payFull) {
          _applyFullAmount();
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _cuentas =>
      (_data?['cuentas'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  List<Map<String, dynamic>> get _pendientes =>
      (_data?['pendientes'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  double get _totalPendienteBase {
    double total = 0;
    for (final p in _pendientes) {
      final tasa = (p['tasa'] as num?)?.toDouble() ?? 1;
      total += ((p['monto_x_pagar'] as num?)?.toDouble() ?? 0) * tasa;
    }
    return total;
  }

  Map<String, dynamic>? get _selectedAccountData {
    if (_selectedAccount == null) return null;
    return _cuentas.firstWhere(
      (c) => c['id_cuenta'] == _selectedAccount,
      orElse: () => {},
    );
  }

  bool get _cuentaEsVes {
    final cuenta = _selectedAccountData;
    if (cuenta == null) return false;
    final moneda = (cuenta['moneda'] ?? '').toString().toUpperCase();
    return moneda.contains('VES') || moneda.contains('BS');
  }

  double get _tasaCuenta =>
      (_selectedAccountData?['tasa'] as num?)?.toDouble() ?? 1.0;

  double get _montoUsd =>
      double.tryParse(_montoUsdCtrl.text.replaceAll(',', '.')) ?? 0;

  double get _montoLocal => _calculateMontoLocal(
        montoUsd: _montoUsd,
        cuentaEsVes: _cuentaEsVes,
        tasa: _tasaCuenta,
      );

  double _calculateMontoLocal({
    required double montoUsd,
    required bool cuentaEsVes,
    required double tasa,
  }) {
    if (montoUsd <= 0) return 0;
    if (!cuentaEsVes) return montoUsd;
    final safeTasa = tasa <= 0 ? 1 : tasa;
    return montoUsd * safeTasa;
  }

  void _applyFullAmount() {
    if (_totalPendienteBase > 0) {
      _montoUsdCtrl.text = _totalPendienteBase.toStringAsFixed(2);
    } else {
      _montoUsdCtrl.clear();
    }
  }

  void _changePayMode(bool payFull) {
    setState(() {
      _payFull = payFull;
      if (_payFull) {
        _applyFullAmount();
      } else {
        _montoUsdCtrl.clear();
      }
    });
  }

  void _onAmountChanged() {
    setState(() {});
  }

  void _goToAmount() {
    setState(() => _step = _ReportStep.amount);
  }

  void _goToSelectBank() {
    if (_payFull) {
      _applyFullAmount();
    }
    if (_montoUsd <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto en USD.')),
      );
      return;
    }
    setState(() => _step = _ReportStep.selectBank);
  }

  void _goToBankDetails(int idCuenta) {
    setState(() {
      _selectedAccount = idCuenta;
      _step = _ReportStep.bankDetails;
    });
  }

  void _goToForm() {
    if (_montoUsd <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto en USD.')),
      );
      return;
    }
    setState(() => _step = _ReportStep.form);
  }

  Future<void> _goToSuccess() async {
    await NotificationService.add(
      title: 'Tu pago esta siendo procesado',
      subtitle: 'Se esta conciliando tu reporte',
      kind: NotificationKind.info,
    );
    setState(() => _step = _ReportStep.success);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaPago,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _fechaPago = picked);
    }
  }

  Future<void> _pickEvidence() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxEvidenceBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El archivo supera el limite de 2 MB.'),
        ),
      );
      return;
    }
    final encoded = base64Encode(bytes);
    final ext = file.path.split('.').last.toLowerCase();
    if (!_allowedEvidenceExt.contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formato no permitido. Usa JPG o PNG.'),
        ),
      );
      return;
    }
    setState(() {
      _evidenceBase64 = 'data:image/$ext;base64,$encoded';
      _evidenceExt = ext;
      _evidenceName = file.name;
      _evidenceBytes = bytes.length;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comprobante adjuntado')),
    );
  }

  Future<void> _submit() async {
    final cuenta = _selectedAccountData;
    if (cuenta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un banco.')),
      );
      return;
    }
    if (_pendientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay deudas pendientes.')),
      );
      return;
    }
    if (_refCtrl.text.trim().isEmpty) {
      setState(() => _formError = 'Agrega la referencia del pago.');
      return;
    }
    final montoUsd = _montoUsd;
    final montoLocal = _calculateMontoLocal(
      montoUsd: montoUsd,
      cuentaEsVes: _cuentaEsVes,
      tasa: _tasaCuenta,
    );
    if (montoLocal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto valido.')),
      );
      return;
    }
    AppHaptics.impact();
    setState(() => _formError = null);

    final notificaciones = _pendientes
        .map((p) => {
              'id_notificacion': p['id_notificacion'],
              'abono': p['monto_x_pagar'],
              'tasa': p['tasa'],
              'id_moneda': p['id_moneda'],
            })
        .toList();

    final pagos = [
      {
        'id_moneda': cuenta['id_moneda'],
        'monto': montoLocal,
        'tasa': cuenta['tasa'],
        'referencia': _refCtrl.text.trim(),
        'id_cuenta': cuenta['id_cuenta'],
      }
    ];

    setState(() => _loading = true);
    try {
      ObservabilityService.logEvent('payment_started', data: {
        'inmueble_id': widget.inmueble.idInmueble,
        'client_uuid': _clientUuid,
      });
      final res = await ApiService.enviarPagoReporte(
        token: widget.token,
        inmuebleId: widget.inmueble.idInmueble,
        fechaPago: _fechaPago.toIso8601String().split('T').first,
        observacion: _obsCtrl.text.trim(),
        notificaciones: notificaciones.cast<Map<String, dynamic>>(),
        pagos: pagos.cast<Map<String, dynamic>>(),
        clientUuid: _clientUuid,
        comprobanteBase64: _evidenceBase64,
        comprobanteExt: _evidenceExt,
      );
      if (!mounted) return;
      if (res['duplicado'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este pago ya fue reportado.')),
        );
        ObservabilityService.logEvent('payment_failed', data: {
          'reason': 'duplicado',
          'inmueble_id': widget.inmueble.idInmueble,
        });
        return;
      }
      await _goToSuccess();
      ObservabilityService.logEvent('payment_success', data: {
        'inmueble_id': widget.inmueble.idInmueble,
        'client_uuid': _clientUuid,
      });
    } catch (e) {
      if (!mounted) return;
      ObservabilityService.logEvent('payment_failed', data: {
        'reason': 'exception',
        'inmueble_id': widget.inmueble.idInmueble,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reportar pago')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reportar pago')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AppEmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'No pudimos cargar los datos del pago.',
              subtitle: 'Revisa tu conexion e intenta de nuevo.',
              actionLabel: 'Reintentar',
              onAction: _load,
            ),
          ),
        ),
      );
    }

    final resumen = _buildSummaryBar();
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar pago')),
      body: Stack(
        children: [
          Column(
            children: [
              if (resumen != null) resumen,
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildStep(),
                ),
              ),
            ],
          ),
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.05),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _ReportStep.amount:
        return _AmountStep(
          totalPendienteBase: _totalPendienteBase,
          payFull: _payFull,
          montoUsdCtrl: _montoUsdCtrl,
          onPayModeChange: _changePayMode,
          onAmountChanged: _onAmountChanged,
          onContinue: _goToSelectBank,
        );
      case _ReportStep.selectBank:
        return _SelectBankStep(
          cuentas: _cuentas,
          amountUsd: _montoUsd,
          onSelect: _goToBankDetails,
          onBack: _goToAmount,
          onBackToAmount: _goToAmount,
        );
      case _ReportStep.bankDetails:
        final cuenta = _selectedAccountData;
        return _BankDetailStep(
          cuenta: cuenta,
          inmueble: widget.inmueble,
          totalPendienteBase: _totalPendienteBase,
          montoUsd: _montoUsd,
          montoLocal: _montoLocal,
          cuentaEsVes: _cuentaEsVes,
          tasaCuenta: _tasaCuenta,
          onContinue: _goToForm,
          onBack: () => setState(() => _step = _ReportStep.selectBank),
        );
      case _ReportStep.form:
        final cuenta = _selectedAccountData;
        return _PaymentFormStep(
          cuenta: cuenta,
          fechaPago: _fechaPago,
          obsCtrl: _obsCtrl,
          refCtrl: _refCtrl,
          cuentaEsVes: _cuentaEsVes,
          montoUsd: _montoUsd,
          montoLocal: _montoLocal,
          tasaCuenta: _tasaCuenta,
          totalPendienteBase: _totalPendienteBase,
          onPickDate: _pickDate,
          onSubmit: _submit,
          onBack: () => setState(() => _step = _ReportStep.bankDetails),
          onPickEvidence: _pickEvidence,
          evidenceLabel: _evidenceLabel,
          evidenceHint: _evidenceHint,
          evidencePreview: _evidencePreview(),
          error: _formError,
        );
      case _ReportStep.success:
        return _SuccessStep(onClose: () => Navigator.of(context).pop(true));
    }
  }

  Widget? _buildSummaryBar() {
    if (_step == _ReportStep.success) return null;
    final cuenta = _selectedAccountData;
    final moneda = (cuenta?['moneda'] ?? '').toString();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppColors.textMuted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: AppColors.brandBlue600.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              IconsRounded.payments,
              color: AppColors.brandBlue600,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monto: ${formatMoney(_montoUsd)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  cuenta == null
                      ? 'Selecciona un banco'
                      : 'Banco: ${cuenta['banco'] ?? cuenta['nombre']} (${moneda.isEmpty ? 'USD' : moneda})',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          if (_montoUsd > 0)
            TextButton(
              onPressed: _goToAmount,
              child: const Text('Editar'),
            ),
        ],
      ),
    );
  }

  String get _evidenceLabel {
    if (_evidenceName != null) {
      final size =
          _evidenceBytes == null ? '' : ' (${_formatBytes(_evidenceBytes!)})';
      return 'Adjuntado: $_evidenceName$size';
    }
    if (_evidenceBase64 != null) return 'Comprobante adjuntado';
    return 'Adjuntar comprobante';
  }

  String get _evidenceHint {
    return 'Formatos: JPG, PNG. Max 2 MB.';
  }

  Widget? _evidencePreview() {
    if (_evidenceBase64 == null) return null;
    final base64 = _evidenceBase64!;
    final bytes = base64.contains(',') ? base64.split(',').last : base64;
    try {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(bytes),
            height: 120,
            fit: BoxFit.cover,
          ),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

}

class _StepHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int step;
  final VoidCallback? onBack;

  const _StepHeader({
    required this.title,
    required this.step,
    this.subtitle,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppColors.textMuted;
    const labels = ['MONTO', 'BANCO', 'RECIBO'];
    const activeColor = AppColors.brandBlue600;
    final inactiveColor = theme.colorScheme.surfaceContainerHighest;
    final lineColor = theme.colorScheme.outline.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (onBack != null)
              AppIconButton(
                icon: IconsRounded.arrow_back,
                tooltip: 'Volver',
                onPressed: onBack,
                size: 44,
                iconSize: 18,
              ),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            _stepDot(
              index: 0,
              step: step,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              lineColor: lineColor,
            ),
            Expanded(child: _stepLine(step > 1, activeColor, lineColor)),
            _stepDot(
              index: 1,
              step: step,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              lineColor: lineColor,
            ),
            Expanded(child: _stepLine(step > 2, activeColor, lineColor)),
            _stepDot(
              index: 2,
              step: step,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
              lineColor: lineColor,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final label in labels)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: muted,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _stepDot({
    required int index,
    required int step,
    required Color activeColor,
    required Color inactiveColor,
    required Color lineColor,
  }) {
    final isActive = step >= index + 1;
    return Container(
      height: 28,
      width: 28,
      decoration: BoxDecoration(
        color: isActive ? activeColor.withValues(alpha: 0.15) : inactiveColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? activeColor : lineColor,
        ),
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isActive ? activeColor : lineColor,
          ),
        ),
      ),
    );
  }

  Widget _stepLine(bool active, Color activeColor, Color lineColor) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: active ? activeColor : lineColor,
    );
  }
}

class _AmountStep extends StatelessWidget {
  final double totalPendienteBase;
  final bool payFull;
  final TextEditingController montoUsdCtrl;
  final ValueChanged<bool> onPayModeChange;
  final VoidCallback onAmountChanged;
  final VoidCallback onContinue;

  const _AmountStep({
    required this.totalPendienteBase,
    required this.payFull,
    required this.montoUsdCtrl,
    required this.onPayModeChange,
    required this.onAmountChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceEffects = AppPerf.reduceEffects(context);
    final muted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppColors.textMuted;
    final hasDebt = totalPendienteBase > 0;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _StepHeader(
          title: 'Monto a reportar',
          subtitle: 'Indica si el pago es total o parcial.',
          step: 1,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outline),
            boxShadow: [
              if (!isDark && !reduceEffects)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Deuda total (USD)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                formatMoney(totalPendienteBase),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Selecciona el monto',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Pago total'),
              selected: payFull,
              showCheckmark: false,
              selectedColor: AppColors.brandBlue600.withValues(alpha: 0.12),
              onSelected: (_) => onPayModeChange(true),
            ),
            ChoiceChip(
              label: const Text('Personalizado'),
              selected: !payFull,
              showCheckmark: false,
              selectedColor: AppColors.brandBlue600.withValues(alpha: 0.12),
              onSelected: (_) => onPayModeChange(false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: montoUsdCtrl,
          readOnly: payFull,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Monto en USD',
            prefixText: '\$',
            suffixText: 'USD',
            helperText:
                payFull ? 'Se usa el total pendiente.' : 'Ingresa el monto en USD.',
            helperStyle: TextStyle(color: muted),
          ),
          onChanged: (_) => onAmountChanged(),
        ),
        const SizedBox(height: 12),
        if (!hasDebt)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceAlt
                  : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              children: [
                const Icon(IconsRounded.verified, color: AppColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No hay deuda pendiente en este inmueble.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!hasDebt) const SizedBox(height: 12),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: hasDebt ? onContinue : null,
          child: const Text('Elegir metodo de pago'),
        ),
      ],
    );
  }
}

class _SelectBankStep extends StatelessWidget {
  final List<Map<String, dynamic>> cuentas;
  final double amountUsd;
  final ValueChanged<int> onSelect;
  final VoidCallback onBack;
  final VoidCallback onBackToAmount;

  const _SelectBankStep({
    required this.cuentas,
    required this.onSelect,
    required this.amountUsd,
    required this.onBack,
    required this.onBackToAmount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceEffects = AppPerf.reduceEffects(context);
    final muted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppColors.textMuted;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StepHeader(
          title: 'Metodo de pago',
          subtitle: 'Elige el banco para reportar tu pago.',
          step: 2,
          onBack: onBack,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Monto en USD: ${formatMoney(amountUsd)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            TextButton(
              onPressed: onBackToAmount,
              child: const Text('Cambiar monto'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (cuentas.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outline),
              boxShadow: [
                if (!isDark && !reduceEffects)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Column(
              children: [
                Icon(IconsRounded.account_balance,
                    color: theme.colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  'No hay bancos disponibles.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Contacta a la administracion para agregar uno.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
              ],
            ),
          )
        else
          ...cuentas.map((c) {
            final moneda = (c['moneda'] ?? '').toString();
            final esVes = moneda.toUpperCase().contains('VES') ||
                moneda.toUpperCase().contains('BS');
            final tasa = (c['tasa'] as num?)?.toDouble() ?? 1;
            final montoLocal =
                amountUsd > 0 ? (esVes ? amountUsd * tasa : amountUsd) : null;
            final banco = c['banco'] ?? c['nombre'] ?? 'Banco';
            final codigo = (c['codigo_banco'] ?? '').toString();

            return InkWell(
              onTap: () => onSelect(c['id_cuenta'] as int),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outline),
                  boxShadow: [
                    if (!isDark && !reduceEffects)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color: AppColors.brandBlue600.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        IconsRounded.account_balance,
                        color: AppColors.brandBlue600,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            banco,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$codigo $moneda'.trim(),
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                          if (montoLocal != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              esVes
                                  ? 'Pagaras: ${formatMoney(montoLocal, withSymbol: false)} $moneda (tasa ${formatMoney(tasa, withSymbol: false)} $moneda/USD)'
                                  : 'Pagaras: ${formatMoney(montoLocal)}',
                              style: TextStyle(
                                color: muted,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(IconsRounded.chevron_right, color: muted),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _BankDetailStep extends StatelessWidget {
  final Map<String, dynamic>? cuenta;
  final Inmueble inmueble;
  final double totalPendienteBase;
  final double montoUsd;
  final double montoLocal;
  final bool cuentaEsVes;
  final double tasaCuenta;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const _BankDetailStep({
    required this.cuenta,
    required this.inmueble,
    required this.totalPendienteBase,
    required this.montoUsd,
    required this.montoLocal,
    required this.cuentaEsVes,
    required this.tasaCuenta,
    required this.onContinue,
    required this.onBack,
  });

  void _copy(BuildContext context, String value) {
    AppHaptics.impact();
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copiado')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceEffects = AppPerf.reduceEffects(context);
    if (cuenta == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Selecciona un banco.'),
            const SizedBox(height: 8),
            TextButton(onPressed: onBack, child: const Text('Volver')),
          ],
        ),
      );
    }

    final monedaLabel = cuenta?['moneda'] ?? (cuentaEsVes ? 'VES' : 'USD');
    final bankCode = (cuenta!['codigo_banco'] ?? '').toString();
    final bankName = (cuenta!['banco'] ?? '').toString();
    final bankLabel = '$bankCode $bankName'.trim();
    final rows = [
      ['Banco', bankLabel],
      ['Cuenta', cuenta!['numero_cuenta_cliente'] ?? '--'],
      ['Titular', cuenta!['titular'] ?? '--'],
      ['CI/RIF', cuenta!['rif'] ?? '--'],
      ['Telefono', cuenta!['celular'] ?? '--'],
    ];

    BoxDecoration cardDecoration() => BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline),
          boxShadow: [
            if (!isDark && !reduceEffects)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
          ],
        );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StepHeader(
          title: 'Datos bancarios',
          subtitle: 'Usa estos datos para realizar el pago.',
          step: 2,
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(),
          child: Column(
            children: rows
                .map(
                  (r) => _InfoRow(
                    label: r[0],
                    value: r[1],
                    onCopy: () => _copy(context, r[1]),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Resumen',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (totalPendienteBase > 0)
                _InfoRow(
                  label: 'Deuda total (USD)',
                  value: formatMoney(totalPendienteBase),
                ),
              _InfoRow(
                label: 'Monto seleccionado (USD)',
                value: formatMoney(montoUsd),
              ),
              _InfoRow(
                label: 'A pagar en $monedaLabel',
                value:
                    '${formatMoney(montoLocal, withSymbol: false)} $monedaLabel',
              ),
              if (cuentaEsVes)
                _InfoRow(
                  label: 'Tasa aplicada',
                  value:
                      '${formatMoney(tasaCuenta, withSymbol: false)} $monedaLabel / USD',
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onContinue,
          child: const Text('Ya realice el pago'),
        ),
      ],
    );
  }
}

class _PaymentFormStep extends StatelessWidget {
  final Map<String, dynamic>? cuenta;
  final DateTime fechaPago;
  final TextEditingController obsCtrl;
  final TextEditingController refCtrl;
  final bool cuentaEsVes;
  final double montoUsd;
  final double montoLocal;
  final double tasaCuenta;
  final double totalPendienteBase;
  final VoidCallback onPickDate;
  final VoidCallback onSubmit;
  final VoidCallback onBack;
  final VoidCallback onPickEvidence;
  final String? evidenceLabel;
  final String? evidenceHint;
  final Widget? evidencePreview;
  final String? error;

  const _PaymentFormStep({
    required this.cuenta,
    required this.fechaPago,
    required this.obsCtrl,
    required this.refCtrl,
    required this.cuentaEsVes,
    required this.montoUsd,
    required this.montoLocal,
    required this.tasaCuenta,
    required this.totalPendienteBase,
    required this.onPickDate,
    required this.onSubmit,
    required this.onBack,
    required this.onPickEvidence,
    required this.evidenceLabel,
    required this.evidenceHint,
    required this.evidencePreview,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fecha = fechaPago.toIso8601String().split('T').first;
    final muted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
            AppColors.textMuted;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StepHeader(
          title: 'Registrar pago',
          subtitle: 'Completa los datos del pago.',
          step: 3,
          onBack: onBack,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: refCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Numero de referencia',
            prefixIcon: Icon(IconsRounded.pin),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onPickDate,
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Fecha del pago',
              suffixIcon: Icon(IconsRounded.calendar_month),
            ),
            child: Text(fecha),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onPickEvidence,
          icon: const Icon(IconsRounded.attach_file),
          label: Text(evidenceLabel ?? 'Adjuntar comprobante'),
        ),
        if (evidenceHint != null) ...[
          const SizedBox(height: 6),
          Text(
            evidenceHint!,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
        if (evidencePreview != null) evidencePreview!,
        const SizedBox(height: 12),
        TextField(
          controller: obsCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Observaciones (opcional)',
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onSubmit,
          child: const Text('Enviar reporte'),
        ),
      ],
    );
  }
}

class _SuccessStep extends StatelessWidget {
  final VoidCallback onClose;
  const _SuccessStep({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppColors.textMuted;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              IconsRounded.check_circle,
              size: 72,
              color: AppColors.success,
            ),
            const SizedBox(height: 16),
            Text(
              'Reporte enviado',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tu pago esta en conciliacion. Te avisaremos cuando se valide.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onClose,
              child: const Text('Volver a detalle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;
  const _InfoRow({required this.label, required this.value, this.onCopy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppColors.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (onCopy != null) ...[
                  const SizedBox(width: 6),
                  AppIconButton(
                    icon: IconsRounded.content_copy,
                    tooltip: 'Copiar',
                    onPressed: onCopy,
                    size: 44,
                    iconSize: 18,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}






