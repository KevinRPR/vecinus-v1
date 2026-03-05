import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class PinPad extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool showBiometric;
  final VoidCallback? onBiometric;
  final double keySize;
  final int resetToken;

  const PinPad({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.errorText,
    this.showBiometric = false,
    this.onBiometric,
    this.length = 4,
    this.keySize = 64,
    this.resetToken = 0,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  final List<int> _digits = [];
  int _lastResetToken = 0;

  @override
  void didUpdateWidget(covariant PinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetToken != _lastResetToken) {
      _lastResetToken = widget.resetToken;
      _digits.clear();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _addDigit(int digit) {
    if (_digits.length >= widget.length) return;
    setState(() => _digits.add(digit));
    final pin = _digits.join();
    widget.onChanged?.call(pin);
    if (_digits.length == widget.length) {
      widget.onCompleted(pin);
    }
  }

  void _backspace() {
    if (_digits.isEmpty) return;
    setState(() => _digits.removeLast());
    widget.onChanged?.call(_digits.join());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted =
        theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppColors.textMuted;
    final primary = theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        const minKeySize = 44.0;
        final spacing = (constraints.maxWidth / 18).clamp(6.0, 12.0);
        final maxCell = (constraints.maxWidth - spacing * 2) / 3;
        final resolvedKeySize = maxCell < minKeySize
            ? maxCell
            : widget.keySize.clamp(minKeySize, maxCell).toDouble();

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.length, (index) {
                final filled = index < _digits.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? primary : muted.withValues(alpha: 0.2),
                  ),
                );
              }),
            ),
            if (widget.errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.errorText!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildKeypad(
              context,
              resolvedKeySize,
              primary,
              muted,
              spacing,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKeypad(
    BuildContext context,
    double keySize,
    Color primary,
    Color muted,
    double spacing,
  ) {
    final fillColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final keys = [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      widget.showBiometric ? 'bio' : '',
      0,
      'back',
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
      ),
      itemBuilder: (context, index) {
        final value = keys[index];
        if (value == '') {
          return const SizedBox.shrink();
        }
        if (value == 'bio') {
          return _pinKey(
            size: keySize,
            icon: Icons.fingerprint,
            label: 'Biometria',
            onTap: widget.onBiometric,
            color: primary,
            fillColor: fillColor,
          );
        }
        if (value == 'back') {
          return _pinKey(
            size: keySize,
            icon: Icons.backspace_outlined,
            label: 'Borrar',
            onTap: _backspace,
            color: muted,
            fillColor: fillColor,
          );
        }
        return _pinKey(
          size: keySize,
          label: value.toString(),
          onTap: () => _addDigit(value as int),
          color: Theme.of(context).colorScheme.onSurface,
          fillColor: fillColor,
        );
      },
    );
  }

  Widget _pinKey({
    required double size,
    required String label,
    required VoidCallback? onTap,
    required Color color,
    required Color fillColor,
    IconData? icon,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onTap,
          radius: size / 2,
          containedInkWell: true,
          highlightShape: BoxShape.circle,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: fillColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, color: color)
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
