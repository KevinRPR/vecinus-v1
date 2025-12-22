import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/inmueble.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

enum _ReportStep { selectBank, bankDetails, form, success }

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
  _ReportStep _step = _ReportStep.selectBank;
  late final String _clientUuid;

  final TextEditingController _obsCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _montoCtrl = TextEditingController();
  final TextEditingController _montoUsdCtrl = TextEditingController();
  final TextEditingController _montoVesCtrl = TextEditingController();
  DateTime _fechaPago = DateTime.now();

  final _picker = ImagePicker();
  String? _evidenceBase64;
  String? _evidenceExt;
  int? _monedaBase;

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
    _montoCtrl.dispose();
    _montoUsdCtrl.dispose();
    _montoVesCtrl.dispose();
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

  void _syncUsdFromVes() {
    final ves = double.tryParse(_montoVesCtrl.text.replaceAll(',', '.')) ?? 0;
    if (_tasaCuenta > 0) {
      final usd = ves / _tasaCuenta;
      _montoUsdCtrl.text = usd.isFinite ? usd.toStringAsFixed(2) : '';
      _montoCtrl.text = _montoVesCtrl.text;
    }
  }

  void _syncVesFromUsd() {
    final usd = double.tryParse(_montoUsdCtrl.text.replaceAll(',', '.')) ?? 0;
    final ves = usd * _tasaCuenta;
    _montoVesCtrl.text = ves.isFinite ? ves.toStringAsFixed(2) : '';
    _montoCtrl.text = _montoVesCtrl.text;
  }

  double get _totalBase {
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;
    return monto * (_tasaCuenta > 0 ? _tasaCuenta : 1);
  }

  void _goToDetails(int idCuenta) {
    setState(() {
      _selectedAccount = idCuenta;
      _step = _ReportStep.bankDetails;
      if (_cuentaEsVes) {
        _montoUsdCtrl.text = '';
        _montoVesCtrl.text = '';
        _montoCtrl.text = '';
      } else {
        _montoCtrl.text = '';
      }
    });
  }

  void _goToForm() {
    setState(() => _step = _ReportStep.form);
  }

  void _goToSuccess() {
    NotificationService.add(
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
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;
    if (monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto valido.')),
      );
      return;
    }

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
        'monto': monto,
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
      _goToSuccess();
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

    return Scaffold(
      appBar: AppBar(title: const Text('Pagar')),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _buildStep(),
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
      case _ReportStep.selectBank:
        return _SelectBankStep(
          cuentas: _cuentas,
          onSelect: _goToDetails,
        );
      case _ReportStep.bankDetails:
        final cuenta = _selectedAccountData;
        return _BankDetailStep(
          cuenta: cuenta,
          inmueble: widget.inmueble,
          totalBase: _totalBase,
          totalPendienteBase: _totalPendienteBase,
          cuentaEsVes: _cuentaEsVes,
          montoUsdCtrl: _montoUsdCtrl,
          montoVesCtrl: _montoVesCtrl,
          onUsdChanged: _syncVesFromUsd,
          onVesChanged: _syncUsdFromVes,
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
          montoCtrl: _montoCtrl,
          montoUsdCtrl: _montoUsdCtrl,
          montoVesCtrl: _montoVesCtrl,
          cuentaEsVes: _cuentaEsVes,
          onUsdChanged: _syncVesFromUsd,
          onVesChanged: _syncUsdFromVes,
          totalPendienteBase: _totalPendienteBase,
          onPickDate: _pickDate,
          onSubmit: _submit,
          onBack: () => setState(() => _step = _ReportStep.bankDetails),
          onPickEvidence: _pickEvidence,
          evidenceLabel: _evidenceBase64 != null ? 'Comprobante adjuntado' : 'Adjuntar comprobante',
        );
      case _ReportStep.success:
        return _SuccessStep(onClose: () => Navigator.of(context).pop(true));
    }
  }
}

class _SelectBankStep extends StatelessWidget {
  final List<Map<String, dynamic>> cuentas;
  final ValueChanged<int> onSelect;

  const _SelectBankStep({
    required this.cuentas,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Por cual banco desea pagar?',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 12),
        if (cuentas.isEmpty)
          const Text('No hay bancos disponibles.')
        else
          ...cuentas.map(
            (c) => Container(
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
                      '${c['codigo_banco'] ?? ''} ${c['moneda'] ?? ''}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BankDetailStep extends StatelessWidget {
  final Map<String, dynamic>? cuenta;
  final Inmueble inmueble;
  final double totalBase;
  final double totalPendienteBase;
  final bool cuentaEsVes;
  final TextEditingController montoUsdCtrl;
  final TextEditingController montoVesCtrl;
  final VoidCallback onUsdChanged;
  final VoidCallback onVesChanged;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const _BankDetailStep({
    required this.cuenta,
    required this.inmueble,
    required this.totalBase,
    required this.totalPendienteBase,
    required this.cuentaEsVes,
    required this.montoUsdCtrl,
    required this.montoVesCtrl,
    required this.onUsdChanged,
    required this.onVesChanged,
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
        _InfoRow(
          label: 'Deuda total (base)',
          value: '\$${totalPendienteBase.toStringAsFixed(2)}',
        ),
        _InfoRow(
          label: 'Equivalente',
          value:
              '${(totalPendienteBase * ((cuenta!['tasa'] as num?)?.toDouble() ?? 1)).toStringAsFixed(2)} ${cuenta!['moneda'] ?? ''}',
        ),
        const SizedBox(height: 12),
        if (cuentaEsVes) ...[
          const Text(
            'Calculadora de divisas',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: montoUsdCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto en USD',
              suffixText: 'USD',
            ),
            onChanged: (_) => onUsdChanged(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: montoVesCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto en VES',
              suffixText: cuenta?['moneda'] ?? 'VES',
              helperText: 'Tasa: ${(cuenta?['tasa'] as num?)?.toDouble() ?? 1} ${cuenta?['moneda'] ?? 'VES'} por USD',
            ),
            onChanged: (_) => onVesChanged(),
          ),
          const SizedBox(height: 16),
        ],
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
  final TextEditingController montoCtrl;
  final TextEditingController montoUsdCtrl;
  final TextEditingController montoVesCtrl;
  final bool cuentaEsVes;
  final VoidCallback onUsdChanged;
  final VoidCallback onVesChanged;
  final double totalPendienteBase;
  final VoidCallback onPickDate;
  final VoidCallback onSubmit;
  final VoidCallback onBack;
  final VoidCallback onPickEvidence;
  final String? evidenceLabel;

  const _PaymentFormStep({
    required this.cuenta,
    required this.fechaPago,
    required this.pendientes,
    required this.obsCtrl,
    required this.refCtrl,
    required this.montoCtrl,
    required this.montoUsdCtrl,
    required this.montoVesCtrl,
    required this.cuentaEsVes,
    required this.onUsdChanged,
    required this.onVesChanged,
    required this.totalPendienteBase,
    required this.onPickDate,
    required this.onSubmit,
    required this.onBack,
    required this.onPickEvidence,
    required this.evidenceLabel,
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
              'Registrar pago',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deuda total',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '\$${totalPendienteBase.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                if (cuenta != null && cuenta!['tasa'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Equivalente: ${(totalPendienteBase * ((cuenta!['tasa'] as num?)?.toDouble() ?? 1)).toStringAsFixed(2)} ${cuenta!['moneda'] ?? ''}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (pendientes.isNotEmpty)
          ...pendientes.map(
            (p) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(
                  p['descripcion'] ?? 'Notificacion',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${p['codigo_moneda']} pendiente: ${p['monto_x_pagar']}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
        TextField(
          controller: refCtrl,
          decoration: const InputDecoration(
            labelText: 'Numero de referencia',
          ),
        ),
        const SizedBox(height: 12),
        if (cuentaEsVes) ...[
          TextField(
            controller: montoUsdCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto en USD',
              suffixText: 'USD',
            ),
            onChanged: (_) => onUsdChanged(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: montoVesCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto en VES',
              suffixText: cuenta?['moneda'] ?? 'VES',
              helperText: 'Tasa: ${(cuenta?['tasa'] as num?)?.toDouble() ?? 1} ${cuenta?['moneda'] ?? 'VES'} por USD',
            ),
            onChanged: (_) => onVesChanged(),
          ),
        ] else
          TextField(
            controller: montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto pagado${cuenta != null ? ' (${cuenta!['moneda']})' : ''}',
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          readOnly: true,
          controller: TextEditingController(
            text: '${fechaPago.year}-${fechaPago.month.toString().padLeft(2, '0')}-${fechaPago.day.toString().padLeft(2, '0')}',
          ),
          decoration: const InputDecoration(
            labelText: 'Fecha del pago',
            suffixIcon: Icon(Icons.calendar_today),
          ),
          onTap: onPickDate,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: obsCtrl,
          decoration: const InputDecoration(
            labelText: 'Observaciones (opcional)',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onPickEvidence,
          icon: const Icon(Icons.attach_file),
          label: Text(evidenceLabel ?? 'Adjuntar comprobante'),
        ),
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
