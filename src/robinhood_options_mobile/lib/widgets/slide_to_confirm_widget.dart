import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SlideToConfirm extends StatefulWidget {
  final String text;
  final VoidCallback onConfirmed;
  final Color backgroundColor;
  final Color sliderColor;
  final Color iconColor;
  final Color textColor;
  final double height;
  final double borderRadius;

  const SlideToConfirm({
    super.key,
    required this.onConfirmed,
    this.text = "Slide to confirm",
    this.backgroundColor = Colors.grey,
    this.sliderColor = Colors.white,
    this.iconColor = Colors.black,
    this.textColor = Colors.white,
    this.height = 50,
    this.borderRadius = 25,
  });

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _position = 0;
  bool _confirmed = false;

  void _triggerConfirm(double maxSlide) {
    if (_confirmed) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _position = maxSlide;
      _confirmed = true;
    });
    widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxSlide = maxWidth - widget.height;

        return Semantics(
          container: true,
          button: true,
          enabled: !_confirmed,
          label: widget.text,
          hint: 'Slide slider or double tap to confirm',
          value: _confirmed ? 'Confirmed' : 'Not confirmed',
          onTap: _confirmed ? null : () => _triggerConfirm(maxSlide),
          child: Container(
            height: widget.height,
            width: maxWidth,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: Stack(
              children: [
                Center(
                  child: ExcludeSemantics(
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        color: widget.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _position,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (_confirmed) return;
                      setState(() {
                        _position += details.delta.dx;
                        if (_position < 0) _position = 0;
                        if (_position > maxSlide) _position = maxSlide;
                      });
                      if (_position >= maxSlide) {
                        HapticFeedback.selectionClick();
                      }
                    },
                    onHorizontalDragEnd: (details) {
                      if (_confirmed) return;
                      if (_position >= maxSlide * 0.9) {
                        _triggerConfirm(maxSlide);
                      } else {
                        setState(() {
                          _position = 0;
                        });
                      }
                    },
                    child: Container(
                      height: widget.height,
                      width: widget.height,
                      decoration: BoxDecoration(
                        color: widget.sliderColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _confirmed ? Icons.check : Icons.arrow_forward,
                        color: widget.iconColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
