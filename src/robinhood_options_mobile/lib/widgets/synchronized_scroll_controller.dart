import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A group of scroll controllers whose scroll offsets are synchronized.
///
/// Designed to link multiple horizontally scrolling rows (such as position detail
/// rows in portfolio lists) so that scrolling any single row scrolls all rows
/// synchronously with smooth momentum, low latency, and without recursive event loops.
class SynchronizedScrollControllerGroup {
  final Set<_LinkedScrollPosition> _attachedPositions = {};
  double _offset = 0.0;

  /// Current horizontal scroll offset of the group.
  double get offset => _offset;

  /// Number of currently attached scroll positions.
  int get attachedCount => _attachedPositions.length;

  /// Creates a [ScrollController] linked to this group.
  ScrollController createScrollController({double? initialScrollOffset}) {
    return _LinkedScrollController(
      this,
      initialScrollOffset: initialScrollOffset ?? _offset,
    );
  }

  void _attach(_LinkedScrollPosition position) {
    _attachedPositions.add(position);
  }

  void _detach(_LinkedScrollPosition position) {
    _attachedPositions.remove(position);
  }

  void _notifyOffset(double newOffset, _LinkedScrollPosition source) {
    _offset = newOffset;
    for (final position in _attachedPositions) {
      if (position != source &&
          position.hasPixels &&
          position.hasContentDimensions) {
        final clamped = newOffset.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if (position.pixels != clamped) {
          position.correctPixels(clamped);
          position.notifyListeners();
        }
      }
    }
  }

  void _onDragStart(_LinkedScrollPosition source) {
    for (final position in _attachedPositions) {
      if (position != source) {
        position.resetActivity();
      }
    }
  }

  /// Programmatically jumps all controllers in this group to [value].
  void jumpTo(double value) {
    _offset = value;
    for (final position in _attachedPositions) {
      if (position.hasPixels && position.hasContentDimensions) {
        final clamped = value.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        position.jumpTo(clamped);
      }
    }
  }

  /// Programmatically animates all controllers in this group to [value].
  Future<void> animateTo(
    double value, {
    required Duration duration,
    required Curve curve,
  }) async {
    _offset = value;
    final futures = <Future<void>>[];
    for (final position in _attachedPositions) {
      if (position.hasPixels && position.hasContentDimensions) {
        final clamped = value.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        futures
            .add(position.animateTo(clamped, duration: duration, curve: curve));
      }
    }
    await Future.wait(futures);
  }

  /// Resets the synchronized offset to zero.
  void reset() {
    _offset = 0.0;
    for (final position in _attachedPositions) {
      if (position.hasPixels && position.hasContentDimensions) {
        position.jumpTo(0.0);
      }
    }
  }
}

class _LinkedScrollController extends ScrollController {
  final SynchronizedScrollControllerGroup group;

  _LinkedScrollController(
    this.group, {
    super.initialScrollOffset = 0.0,
  }) : super(
          keepScrollOffset: false,
        );

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _LinkedScrollPosition(
      group: group,
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
    );
  }
}

class _LinkedScrollPosition extends ScrollPositionWithSingleContext {
  final SynchronizedScrollControllerGroup group;

  _LinkedScrollPosition({
    required this.group,
    required super.physics,
    required super.context,
    super.initialPixels = 0.0,
    super.keepScrollOffset = true,
    super.oldPosition,
  }) {
    group._attach(this);
  }

  void resetActivity() {
    goIdle();
  }

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    group._onDragStart(this);
    return super.drag(details, dragCancelCallback);
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    final result =
        super.applyContentDimensions(minScrollExtent, maxScrollExtent);
    if (group.offset != 0.0 && pixels != group.offset) {
      final clamped = group.offset.clamp(minScrollExtent, maxScrollExtent);
      correctPixels(clamped);
    }
    return result;
  }

  @override
  double setPixels(double newPixels) {
    final overscroll = super.setPixels(newPixels);
    group._notifyOffset(pixels, this);
    return overscroll;
  }

  @override
  void dispose() {
    group._detach(this);
    super.dispose();
  }
}

/// A widget that wraps a horizontally scrollable row and connects it to a [SynchronizedScrollControllerGroup].
class SynchronizedDetailScrollRow extends StatefulWidget {
  final SynchronizedScrollControllerGroup scrollGroup;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  const SynchronizedDetailScrollRow({
    super.key,
    required this.scrollGroup,
    required this.child,
    this.padding,
    this.physics,
  });

  @override
  State<SynchronizedDetailScrollRow> createState() =>
      _SynchronizedDetailScrollRowState();
}

class _SynchronizedDetailScrollRowState
    extends State<SynchronizedDetailScrollRow> {
  late ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.scrollGroup.createScrollController();
  }

  @override
  void didUpdateWidget(covariant SynchronizedDetailScrollRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollGroup != widget.scrollGroup) {
      _controller.dispose();
      _controller = widget.scrollGroup.createScrollController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    if (widget.padding != null) {
      content = Padding(
        padding: widget.padding!,
        child: content,
      );
    }
    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: widget.physics,
      child: content,
    );
  }
}
