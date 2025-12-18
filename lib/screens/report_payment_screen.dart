import 'package:flutter/material.dart';

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

  final TextEditingController _obsCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _montoCtrl = TextEditingController();
  DateTime _fechaPago = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
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

  Map<String, dynamic>? get _selectedAccountData {
    if (_selectedAccount == null) return null;
    return _cuentas.firstWhere(
      (c) => c['id_cuenta'] == _selectedAccount,
      orElse: () => {},
    );
  }

  double get _totalBase => _pendientes.fold(
        0.0,
        (sum, p) => sum + (p['monto_x_pagar'] as num) * (p['tasa'] as num),
      );

  void _goToDetails(int idCuenta) {
    setState(() {
      _selectedAccount = idCuenta;
      _step = _ReportStep.bankDetails;
      final cuenta = _selectedAccountData;
      if (cuenta != null) {
        final sugerido =
            _totalBase / ((cuenta['tasa'] as num?)?.toDouble() ?? 1.0);
        _montoCtrl.text =
            sugerido.isFinite ? sugerido.toStringAsFixed(2) : '';
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
      await ApiService.enviarPagoReporte(
        token: widget.token,
        inmuebleId: widget.inmueble.idInmueble,
        fechaPago: _fechaPago.toIso8601String().split('T').first,
        observacion: _obsCtrl.text.trim(),
        notificaciones: notificaciones.cast<Map<String, dynamic>>(),
        pagos: pagos.cast<Map<String, dynamic>>(),
      );
      if (!mounted) return;
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
          onPickDate: _pickDate,
          onSubmit: _submit,
          onBack: () => setState(() => _step = _ReportStep.bankDetails),
        );
      case _ReportStep.success:
        return _SuccessStep(onClose: () => Navigator.of(context).pop(true));
    }
  }

  String _format(num n) => '\$${n.toStringAsFixed(2)}';
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
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${c['codigo_banco'] ?? ''} • ${c['moneda'] ?? ''}',
                      style: TextStyle(color: Colors.grey.shade700),
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
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const _BankDetailStep({
    required this.cuenta,
    required this.inmueble,
    required this.totalBase,
    required this.onContinue,
    required this.onBack,
  });

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
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InfoRow(label: 'Banco', value: '${cuenta!['codigo_banco'] ?? ''} ${cuenta!['banco'] ?? ''}'),
        _InfoRow(label: 'Cuenta', value: cuenta!['numero_cuenta_cliente'] ?? '--'),
        _InfoRow(label: 'Titular', value: cuenta!['titular'] ?? '--'),
        _InfoRow(label: 'CI/RIF', value: cuenta!['rif'] ?? '--'),
        _InfoRow(label: 'Telefono', value: cuenta!['celular'] ?? '--'),
        const SizedBox(height: 16),
        _InfoRow(label: 'Total a pagar (base)', value: '\$${totalBase.toStringAsFixed(2)}'),
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
  final VoidCallback onPickDate;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const _PaymentFormStep({
    required this.cuenta,
    required this.fechaPago,
    required this.pendientes,
    required this.obsCtrl,
    required this.refCtrl,
    required this.montoCtrl,
    required this.onPickDate,
    required this.onSubmit,
    required this.onBack,
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
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (pendientes.isNotEmpty)
          ...pendientes.map(
            (p) => ListTile(
              dense: true,
              title: Text(p['descripcion'] ?? 'Notificacion'),
              subtitle: Text('${p['codigo_moneda']} ${p['monto_x_pagar']}'),
            ),
          ),
        TextField(
          controller: refCtrl,
          decoration: const InputDecoration(
            labelText: 'Numero de referencia',
          ),
        ),
        const SizedBox(height: 12),
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
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
