import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnimatedPriceText extends StatefulWidget {
  final double price;
  final NumberFormat? format;
  final TextStyle? style;
  final Duration duration;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool? softWrap;
  final Color? flashColorUp;
  final Color? flashColorDown;

  const AnimatedPriceText({
    super.key,
    required this.price,
    this.format,
    this.style,
    this.duration = const Duration(milliseconds: 750), // 500
    this.overflow,
    this.textAlign,
    this.maxLines,
    this.softWrap,
    this.flashColorUp,
    this.flashColorDown,
  });

  @override
  State<AnimatedPriceText> createState() => _AnimatedPriceTextState();
}

class _AnimatedPriceTextState extends State<AnimatedPriceText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    // Initialize with no animation
    _colorAnimation = AlwaysStoppedAnimation(widget.style?.color);
  }

  @override
  void didUpdateWidget(AnimatedPriceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.price != oldWidget.price) {
      Color targetColor;
      final brightness = Theme.of(context).brightness;
      final defaultUpColor = brightness == Brightness.light
          ? Colors.green
          : Colors.lightGreenAccent;
      final defaultDownColor =
          brightness == Brightness.light ? Colors.red : Colors.redAccent;

      if (widget.price > oldWidget.price) {
        targetColor = widget.flashColorUp ?? defaultUpColor;
      } else if (widget.price < oldWidget.price) {
        targetColor = widget.flashColorDown ?? defaultDownColor;
      } else {
        targetColor = widget.style?.color ??
            DefaultTextStyle.of(context).style.color ??
            Theme.of(context).textTheme.bodyMedium?.color ??
            Colors.black;
      }

      // Resolve the end color (original text color)
      final endColor = widget.style?.color ??
          DefaultTextStyle.of(context).style.color ??
          Theme.of(context).textTheme.bodyMedium?.color;

      // Animate from flash color back to original color
      _colorAnimation = ColorTween(
        begin: targetColor,
        end: endColor,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.format != null
        ? widget.format!.format(widget.price)
        : widget.price.toString();

    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Text(
          text,
          style: (widget.style ?? const TextStyle()).copyWith(
            color: _controller.isAnimating
                ? _colorAnimation.value
                : widget.style?.color,
          ),
          overflow: widget.overflow,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          softWrap: widget.softWrap,
        );
      },
    );
  }
}
