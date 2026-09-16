import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/constants.dart';

class PnlBadge extends StatelessWidget {
  final String? text;
  final Widget? child;
  final double? value;
  final double fontSize;
  final bool neutral;
  final EdgeInsetsGeometry? padding;

  const PnlBadge({
    super.key,
    this.text,
    this.child,
    this.value,
    this.fontSize = badgeValueFontSize,
    this.neutral = false,
    this.padding,
  });

  Color _pnlColor(BuildContext context, double? value) {
    if (value == null) {
      return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    }
    if (value > 0) return Colors.green;
    if (value < 0) return Colors.red;
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final color = neutral
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : _pnlColor(context, value);

    final backgroundColor = neutral
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : color.withValues(alpha: 0.15);

    final borderColor = neutral
        ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)
        : color.withValues(alpha: 0.3);

    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: child ??
          Text(
            text ?? '',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
    );
  }
}
