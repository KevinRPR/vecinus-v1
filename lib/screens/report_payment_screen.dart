import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/inmueble.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

enum _ReportStep { amount, selectBank, bankDetails, form, success }

class ReportPaymentScreen extends StatefulWidget {
  final String token;
  final Inmueble inmueble;

  const ReportPaymentScreen({
    super.key,
    required this.token,
    required this.inmueble,
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
  int? _monedaBase;
  String? _formError;

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
      final res = await ApiService.preparePagoReporte(
        token: widget.token,
        inmuebleId: widget.inmueble.idInmueble,
      );
      setState(() {
        _data = res;
        _monedaBase = res['moneda_base'] is int
            ? res['moneda_base'] as int
            : int.tryParse(res['moneda_base']?.toString() ?? '');
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

  double get _montoLocal => _cuentaEsVes ? _montoUsd * _tasaCuenta : _montoUsd;

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
    final encoded = base64Encode(bytes);
    final ext = file.path.split('.').last.toLowerCase();
    setState(() {
      _evidenceBase64 = 'data:image/$ext;base64,$encoded';
      _evidenceExt = ext;
      _evidenceName = file.name;
    });
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
    final montoLocal = _cuentaEsVes ? montoUsd * _tasaCuenta : montoUsd;
    if (montoLocal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto valido.')),
      );
      return;
    }
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
      }
      await _goToSuccess();
    } catch (e) {
      if (!mounted) return;
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
        appBar: AppBar(title: const Text('Pagar')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pagar')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final resumen = _buildSummaryBar();
    return Scaffold(
      appBar: AppBar(title: const Text('Pagar')),
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
                color: Colors.black.withOpacity(0.05),
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
          cuentaSeleccionada: _selectedAccountData,
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
          pendientes: _pendientes,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff182032) : const Color(0xffe7f1ff),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.summarize, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monto: \$${_montoUsd.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  cuenta == null
                      ? 'Sin banco elegido'
                      : 'Banco: ${cuenta['banco'] ?? cuenta['nombre']} (${moneda.isEmpty ? 'USD' : moneda})',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
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
    if (_evidenceName != null) return 'Adjuntado: $_evidenceName';
    if (_evidenceBase64 != null) return 'Comprobante adjuntado';
    return 'Adjuntar comprobante';
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
}

class _AmountStep extends StatelessWidget {
  final double totalPendienteBase;
  final bool payFull;
  final TextEditingController montoUsdCtrl;
  final ValueChanged<bool> onPayModeChange;
  final VoidCallback onAmountChanged;
  final VoidCallback onContinue;
  final Map<String, dynamic>? cuentaSeleccionada;

  const _AmountStep({
    required this.totalPendienteBase,
    required this.payFull,
    required this.montoUsdCtrl,
    required this.onPayModeChange,
    required this.onAmountChanged,
    required this.onContinue,
    required this.cuentaSeleccionada,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Cuanto deseas pagar?',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Deuda total (USD)', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  '\$${totalPendienteBase.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: true,
                groupValue: payFull,
                title: const Text('Pagar todo'),
                onChanged: (_) => onPayModeChange(true),
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: false,
                groupValue: payFull,
                title: const Text('Monto personalizado'),
                onChanged: (_) => onPayModeChange(false),
              ),
            ),
          ],
        ),
        TextField(
          controller: montoUsdCtrl,
          readOnly: payFull,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monto en USD',
            suffixText: 'USD',
          ),
          onChanged: (_) => onAmountChanged(),
        ),
        const SizedBox(height: 16),
        if (cuentaSeleccionada != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.account_balance, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Usarás ${cuentaSeleccionada?['banco'] ?? cuentaSeleccionada?['nombre'] ?? 'la cuenta seleccionada'}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ElevatedButton(
          onPressed: onContinue,
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            ),
            Text(
              'Elige el metodo de pago',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onBackToAmount,
          child: const Text('Cambiar monto'),
        ),
        if (amountUsd > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Monto en USD: \$${amountUsd.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        if (cuentas.isEmpty)
          const Text('No hay bancos disponibles.')
        else
          ...cuentas.map((c) {
            final moneda = (c['moneda'] ?? '').toString();
            final esVes = moneda.toUpperCase().contains('VES') || moneda.toUpperCase().contains('BS');
            final tasa = (c['tasa'] as num?)?.toDouble() ?? 1;
            final montoLocal = amountUsd > 0 ? (esVes ? amountUsd * tasa : amountUsd) : null;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () => onSelect(c['id_cuenta'] as int),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c['banco'] ?? c['nombre'] ?? 'Banco',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${c['codigo_banco'] ?? ''} $moneda',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                    if (montoLocal != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        esVes
                            ? 'Pagaras: ${montoLocal.toStringAsFixed(2)} $moneda (tasa ${tasa.toStringAsFixed(2)} $moneda/USD)'
                            : 'Pagaras: \$${montoLocal.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
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
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copiado al portapapeles')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
    final rows = [
      ['Banco', '${cuenta!['codigo_banco'] ?? ''} ${cuenta!['banco'] ?? ''}'],
      ['Cuenta', cuenta!['numero_cuenta_cliente'] ?? '--'],
      ['Titular', cuenta!['titular'] ?? '--'],
      ['CI/RIF', cuenta!['rif'] ?? '--'],
      ['Telefono', cuenta!['celular'] ?? '--'],
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            ),
            Text(
              'Datos bancarios',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...rows.map(
          (r) => _InfoRow(
            label: r[0],
            value: r[1],
            onCopy: () => _copy(context, r[1]),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Resumen',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (totalPendienteBase > 0)
          _InfoRow(
            label: 'Deuda total (USD)',
            value: '\$${totalPendienteBase.toStringAsFixed(2)}',
          ),
        _InfoRow(
          label: 'Monto seleccionado (USD)',
          value: '\$${montoUsd.toStringAsFixed(2)}',
        ),
        _InfoRow(
          label: 'A pagar en $monedaLabel',
          value: '${montoLocal.toStringAsFixed(2)} $monedaLabel',
        ),
        if (cuentaEsVes)
          _InfoRow(
            label: 'Tasa aplicada',
            value: '${tasaCuenta.toStringAsFixed(2)} $monedaLabel / USD',
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
  final List<Map<String, dynamic>> pendientes;
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
  final Widget? evidencePreview;
  final String? error;

  const _PaymentFormStep({
    required this.cuenta,
    required this.fechaPago,
    required this.pendientes,
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
    required this.evidencePreview,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monedaLabel = cuenta?['moneda'] ?? (cuentaEsVes ? 'VES' : 'USD');
    final tasa = tasaCuenta > 0 ? tasaCuenta : 1;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            ),
            Text(
              'Registrar pago',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: refCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Numero de referencia',
            prefixIcon: Icon(Icons.pin),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onPickEvidence,
          icon: const Icon(Icons.attach_file),
          label: Text(evidenceLabel ?? 'Adjuntar comprobante'),
        ),
        if (evidencePreview != null) evidencePreview!,
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onSubmit,
          child: const Text('Procesar'),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
      const Icon(Icons.celebration, size: 72, color: Color(0xff1d9bf0)),
          const SizedBox(height: 16),
          const Text(
            'Su pago esta por conciliacion',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text('Actualizaremos el estado en cuanto se valide.'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onClose,
            child: const Text('Cerrar'),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xff475467),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (onCopy != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: onCopy,
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
