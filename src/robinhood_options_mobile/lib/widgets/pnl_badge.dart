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

  String _semanticLabel() {
    final displayText = text ?? '';
    if (neutral) {
      return displayText.isNotEmpty ? '$displayText, neutral' : 'Neutral';
    }
    if (value != null) {
      if (value! > 0) {
        return displayText.isNotEmpty
            ? 'Profit: $displayText'
            : 'Profit: $value';
      } else if (value! < 0) {
        return displayText.isNotEmpty ? 'Loss: $displayText' : 'Loss: $value';
      } else {
        return displayText.isNotEmpty ? '$displayText, neutral' : 'Neutral';
      }
    }
    if (displayText.startsWith('+')) {
      return 'Profit: $displayText';
    } else if (displayText.startsWith('-')) {
      return 'Loss: $displayText';
    }
    return displayText;
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

    final label = _semanticLabel();

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      child: Container(
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
      ),
    );
  }
}
