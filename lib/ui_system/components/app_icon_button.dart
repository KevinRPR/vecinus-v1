import 'package:flutter/material.dart';

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final String? semanticsLabel;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? iconColor;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.semanticsLabel,
    this.onPressed,
    this.size = 44,
    this.iconSize = 20,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    final iconTint = iconColor ?? theme.colorScheme.onSurface;
    final border = theme.colorScheme.outline.withValues(alpha: 0.4);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticsLabel ?? tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: onPressed,
            radius: size / 2,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: border),
              ),
              child: Icon(icon, size: iconSize, color: iconTint),
            ),
          ),
        ),
      ),
    );
  }
}

