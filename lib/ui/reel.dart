import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Motion model for a strip of colour bands that slides under a fixed lens.
///
/// The strip tracks the finger exactly, keeps its momentum when flung and
/// rests wherever it is let go. Only a tapped band glides into the lens.
class ReelMotion({
  required TickerProvider vsync,
  required final VoidCallback onStart,
  required final ValueChanged<double> onChanged,
  required final VoidCallback onEnd,
}) extends ChangeNotifier {
  static const double _flingReach = 0.32;
  static const double _overscrollGive = 0.3;

  late final Ticker _ticker;

  this {
    _ticker = vsync.createTicker(_tick);
  }

  double min = 0;
  double max = 100;
  double step = 5;
  double pixelsPerUnit = 10;
  bool wraps = false;

  /// When true, larger values sit before the lens (above it, or to its left).
  bool reversed = false;

  double _position = 0;
  double _raw = 0;
  double _target = 0;
  double _distance = 0;
  double _decay = 11;
  bool _engaged = false;
  bool _dragging = false;
  bool _pastEnd = false;
  int? _lastNotch;

  /// Unwrapped position of the lens along the strip, in channel units.
  double get position => _position;
  bool get isEngaged => _engaged;
  bool get isDragging => _dragging;
  double get _paintSign => reversed ? -1.0 : 1.0;

  /// How far the strip is pulled past its end, in pixels along the axis.
  /// The sign follows the finger; zero while the value is in range.
  double get overshoot {
    if (wraps) return 0;
    final past = _position - _position.clamp(min, max);
    return -_paintSign * past * pixelsPerUnit;
  }

  /// Follows an outside value while nobody is touching the reel.
  void sync(double value) {
    if (_engaged || _position == value) return;
    _position = value;
    notifyListeners();
  }

  /// Channel value drawn [pixelsFromLens] away from the lens centre.
  double valueAt(double pixelsFromLens) => _position + _paintSign * pixelsFromLens / pixelsPerUnit;

  /// Stops a moving reel under the finger. Returns whether it was moving.
  bool hold() {
    if (!_ticker.isActive) return false;
    _ticker.stop();
    return true;
  }

  void dragStart() {
    hold();
    _engage();
    _dragging = true;
    _raw = _position;
  }

  void dragBy(double deltaPixels) {
    if (!_dragging) return;
    _raw -= _paintSign * deltaPixels / pixelsPerUnit;
    _position = wraps ? _raw : _withOverscrollGive(_raw);
    final pastEnd = !wraps && (_raw < min || _raw > max);
    if (pastEnd && !_pastEnd) HapticFeedback.mediumImpact();
    _pastEnd = pastEnd;
    _emit();
  }

  void release(double pixelsPerSecond) {
    if (!_dragging) return;
    _dragging = false;
    _pastEnd = false;
    final velocity = -_paintSign * pixelsPerSecond / pixelsPerUnit;
    _settleTo(_inRange(_position + velocity * _flingReach), velocity: velocity);
  }

  /// Slides freely by [deltaPixels], for wheels and trackpads.
  void scrollBy(double deltaPixels) {
    hold();
    _engage();
    final next = _position - _paintSign * deltaPixels / pixelsPerUnit;
    _position = wraps ? next : next.clamp(min, max).toDouble();
    _emit();
  }

  /// Comes to rest where it is, gliding back first if pulled past an end.
  void settle() {
    if (_dragging) return;
    _engage();
    _settleTo(_inRange(_position));
  }

  /// Glides to the band nearest to [value].
  void animateTo(double value) {
    hold();
    _engage();
    _settleTo(_snap(value));
  }

  /// Moves by exactly [delta] units, without snapping to a band.
  void nudge(double delta) {
    hold();
    _dragging = false;
    _engage();
    final next = _position + delta;
    _finish(wraps ? next : next.clamp(min, max).toDouble());
  }

  double _snap(double value) => _inRange((value / step).roundToDouble() * step);

  double _inRange(double value) => wraps ? value : value.clamp(min, max).toDouble();

  double _withOverscrollGive(double raw) {
    if (raw < min) return min + (raw - min) * _overscrollGive;
    if (raw > max) return max + (raw - max) * _overscrollGive;
    return raw;
  }

  void _engage() {
    if (_engaged) return;
    _engaged = true;
    _lastNotch = null;
    onStart();
  }

  void _settleTo(double target, {double velocity = 0}) {
    _ticker.stop();
    _target = target;
    _distance = target - _position;
    if (_distance.abs() * pixelsPerUnit < 0.5) {
      _finish(target);
      return;
    }
    final carriesMomentum = velocity * _distance > 0;
    _decay = carriesMomentum ? (velocity / _distance).abs().clamp(5.0, 14.0).toDouble() : 11.0;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final remaining = _distance * math.exp(-_decay * seconds);
    if (remaining.abs() * pixelsPerUnit < 0.4) {
      _finish(_target);
      return;
    }
    _position = _target - remaining;
    _emit();
  }

  void _finish(double restingPosition) {
    _ticker.stop();
    _position = restingPosition;
    _emit();
    if (wraps) _position = _wrapped(_position);
    if (_engaged) {
      _engaged = false;
      onEnd();
    }
    notifyListeners();
  }

  double _wrapped(double position) {
    final span = max - min;
    return min + ((position - min) % span + span) % span;
  }

  void _emit() {
    final value = wraps ? _wrapped(_position) : _position.clamp(min, max).toDouble();
    // Past the end the value is pinned, so the notches stop clicking.
    final notch = ((wraps ? _position : value) / step).round();
    if (_lastNotch != null && _lastNotch != notch) {
      HapticFeedback.selectionClick();
    }
    _lastNotch = notch;
    notifyListeners();
    onChanged(value);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// Turns drags, flings, taps and wheel scrolling into [ReelMotion] calls.
class const ReelSurface({
  super.key,
  required final ReelMotion motion,
  required final Axis axis,
  required final Widget child,
  final ValueChanged<bool>? onPressedChanged,
}) extends StatefulWidget {
  @override
  State<ReelSurface> createState() => _ReelSurfaceState();
}

class _ReelSurfaceState() extends State<ReelSurface> {
  static const Duration _wheelRest = Duration(milliseconds: 160);

  Timer? _wheelTimer;
  bool _caughtWhileMoving = false;
  bool _pressed = false;

  bool get _isVertical => widget.axis == Axis.vertical;

  @override
  void dispose() {
    _wheelTimer?.cancel();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
    widget.onPressedChanged?.call(pressed);
  }

  void _handleDragStart(DragStartDetails details) {
    _wheelTimer?.cancel();
    _setPressed(true);
    widget.motion.dragStart();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    widget.motion.dragBy(details.primaryDelta ?? 0);
  }

  void _handleDragEnd(DragEndDetails details) {
    _setPressed(false);
    widget.motion.release(details.primaryVelocity ?? 0);
  }

  void _handleDragCancel() {
    _setPressed(false);
    widget.motion.release(0);
  }

  void _handleTapUp(TapUpDetails details, Size size) {
    if (_caughtWhileMoving) {
      widget.motion.settle();
      return;
    }
    final fromLens = _isVertical
        ? details.localPosition.dy - size.height / 2
        : details.localPosition.dx - size.width / 2;
    widget.motion.animateTo(widget.motion.valueAt(fromLens));
  }

  void _handleScroll(PointerScrollEvent event) {
    final delta = _isVertical || event.scrollDelta.dx.abs() < event.scrollDelta.dy.abs()
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (delta == 0) return;
    widget.motion.scrollBy(-delta);
    _wheelTimer?.cancel();
    _wheelTimer = Timer(_wheelRest, widget.motion.settle);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          onPointerDown: (_) {
            _caughtWhileMoving = widget.motion.hold();
          },
          onPointerCancel: (_) {
            if (!widget.motion.isDragging) widget.motion.settle();
          },
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) _handleScroll(signal);
          },
          child: MouseRegion(
            cursor: _pressed ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onVerticalDragStart: _isVertical ? _handleDragStart : null,
              onVerticalDragUpdate: _isVertical ? _handleDragUpdate : null,
              onVerticalDragEnd: _isVertical ? _handleDragEnd : null,
              onVerticalDragCancel: _isVertical ? _handleDragCancel : null,
              onHorizontalDragStart: _isVertical ? null : _handleDragStart,
              onHorizontalDragUpdate: _isVertical ? null : _handleDragUpdate,
              onHorizontalDragEnd: _isVertical ? null : _handleDragEnd,
              onHorizontalDragCancel: _isVertical ? null : _handleDragCancel,
              onTapUp: (details) => _handleTapUp(details, size),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// Paints the bands of a reel around the lens at the centre of the canvas.
class ReelStripPainter({
  required final ReelMotion motion,
  required final Axis axis,
  required final Color Function(double value) colorAt,

  /// Changes whenever [colorAt] would return different colours.
  required final Object paletteKey,
}) extends CustomPainter {
  static const double _endRadius = 20;
  static const double _seamOverlap = 0.5;

  this : super(repaint: motion);

  @override
  void paint(Canvas canvas, Size size) {
    final isVertical = axis == Axis.vertical;
    final length = isVertical ? size.height : size.width;
    final breadth = isVertical ? size.width : size.height;
    final lens = length / 2;
    final sign = motion.reversed ? -1.0 : 1.0;
    final unit = motion.pixelsPerUnit;
    final bandLength = motion.step * unit;
    if (bandLength <= 0) return;

    Rect span(double from, double to) {
      final start = math.min(from, to);
      final end = math.max(from, to);
      return isVertical ? Rect.fromLTRB(0, start, breadth, end) : Rect.fromLTRB(start, 0, end, breadth);
    }

    double centreOf(double value) => lens + sign * (value - motion.position) * unit;

    final reach = lens / unit + motion.step;
    var first = ((motion.position - reach) / motion.step).floor();
    var last = ((motion.position + reach) / motion.step).ceil();
    if (!motion.wraps) {
      first = math.max(first, (motion.min / motion.step).round());
      last = math.min(last, (motion.max / motion.step).round());
    }

    if (!motion.wraps) {
      // The strip ends like a cut ribbon: a rounded end, nothing beyond it.
      final ends = span(centreOf(motion.min) - sign * bandLength / 2, centreOf(motion.max) + sign * bandLength / 2);
      canvas.clipRRect(RRect.fromRectAndRadius(ends, const Radius.circular(_endRadius)));
    }

    final paint = Paint();
    for (var band = first; band <= last; band++) {
      final value = band * motion.step;
      final centre = centreOf(value);
      paint.color = colorAt(value);
      canvas.drawRect(span(centre - bandLength / 2 - _seamOverlap, centre + bandLength / 2 + _seamOverlap), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ReelStripPainter oldDelegate) {
    return oldDelegate.paletteKey != paletteKey || oldDelegate.axis != axis || oldDelegate.motion != motion;
  }
}

/// The fixed window at the centre of a reel showing the exact picked colour.
class const ReelLens({
  super.key,
  required final Color color,
  required final bool pressed,

  /// A quiet lens only previews a colour; it is not the one being picked.
  final bool quiet = false,

  /// How hard the end of the strip pushes the lens, in pixels: the strip's
  /// [ReelMotion.overshoot] along the reel's axis.
  final Offset push = Offset.zero,
  final Widget? child,
}) extends StatelessWidget {
  static const double radius = 16;
  static const double _maxShift = 9;
  static const double _pushScale = 36;

  // In pixels rather than as a scale, so wide and narrow lenses grow alike
  // and never reach the edges of their reel.
  static const double _pressGrowth = 3;
  static const double _maxSquash = 4;
  static const double _maxBulge = 2;

  @override
  Widget build(BuildContext context) {
    // Eases toward 1, so a long pull never runs away.
    final give = 1 - math.exp(-push.distance / _pushScale);
    final direction = push == Offset.zero ? Offset.zero : push / push.distance;
    final along = Offset(direction.dx.abs(), direction.dy.abs()) * give;

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => TweenAnimationBuilder<double>(
          tween: Tween(end: pressed ? 1 : 0),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          builder: (context, press, lens) {
            final growth = _pressGrowth * press;
            final size = constraints.biggest;
            return Transform.translate(
              offset: direction * _maxShift * give,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(
                  1 + (growth - _maxSquash * along.dx + _maxBulge * along.dy) / size.width,
                  1 + (growth - _maxSquash * along.dy + _maxBulge * along.dx) / size.height,
                  1,
                ),
                child: lens,
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: quiet ? 0.55 : 1),
                width: quiet ? 1.5 : 2.5,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: quiet ? 0 : 0.22), blurRadius: 1.5),
                BoxShadow(
                  color: Colors.black.withValues(alpha: quiet ? 0 : (pressed ? 0.30 : 0.20) + 0.08 * give),
                  blurRadius: (pressed ? 22 : 12) + 10 * give,
                  offset: Offset(0, pressed ? 8 : 4) + direction * 10 * give,
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
