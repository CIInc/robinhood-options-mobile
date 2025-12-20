import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxSlide = maxWidth - widget.height;

        return Container(
          height: widget.height,
          width: maxWidth,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: widget.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
                  },
                  onHorizontalDragEnd: (details) {
                    if (_confirmed) return;
                    if (_position >= maxSlide * 0.9) {
                      setState(() {
                        _position = maxSlide;
                        _confirmed = true;
                      });
                      widget.onConfirmed();
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
                      Icons.arrow_forward,
                      color: widget.iconColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
