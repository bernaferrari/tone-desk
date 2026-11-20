import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

import '../model/color_math.dart';
import 'chrome.dart';

/// Keeps a cursor for a whole drag, even after the pointer leaves the control.
class DragCursor() {
  OverlayEntry? _entry;

  void show(BuildContext context, MouseCursor cursor) {
    hide();
    final entry = _entry = OverlayEntry(
      builder: (_) => MouseRegion(cursor: cursor, child: const SizedBox.expand()),
    );
    Overlay.of(context).insert(entry);
  }

  void hide() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }
}

/// Eases a control to a value it didn't set itself, like a reset or an undo,
/// and follows the pointer exactly while [instant].
class const Glide({
  super.key,
  required final double value,
  required final Widget Function(double value) builder,
  final bool instant = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: instant ? Duration.zero : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => builder(v),
    );
  }
}

bool _sameColors(List<Color> a, List<Color> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class const _KeyboardAdjustment({
  required final String label,
  required final ValueChanged<int> onStep,
  final VoidCallback? onActivate,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<_KeyboardAdjustment> createState() => _KeyboardAdjustmentState();
}

class _KeyboardAdjustmentState() extends State<_KeyboardAdjustment> {
  bool _focused = false;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.arrowRight:
        widget.onStep(1);
      case LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.arrowLeft:
        widget.onStep(-1);
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.space when widget.onActivate != null:
        if (event is KeyDownEvent) widget.onActivate!();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    debugLabel: widget.label,
    onKeyEvent: _handleKey,
    onFocusChange: (value) => setState(() => _focused = value),
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: _focused ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
      ),
      child: widget.child,
    ),
  );
}

/// A rotary hue knob, a sibling of [TickKnob]: its ring of ticks is the color
/// wheel, and its cap wears the color it makes. Drag it sideways or up and down.
class const HueKnob({
  super.key,
  required final double hue,
  required final List<Color> ring,
  required final ValueChanged<double> onChanged,
  final String label = 'Hue',
  final double? unity,
  final VoidCallback? onStart,
  final VoidCallback? onEnd,
  final VoidCallback? onReset,
  final double size = 52,
  final Color? center,

  /// The ring that sets the cap off from what's behind it.
  final Color? rim,
  final VoidCallback? onTap,
}) extends StatefulWidget {
  @override
  State<HueKnob> createState() => _HueKnobState();
}

class _HueKnobState() extends State<HueKnob> {
  final _cursor = DragCursor();
  bool _active = false;
  bool _hovered = false;

  @override
  void dispose() {
    _cursor.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _KeyboardAdjustment(
      label: widget.label,
      onStep: (direction) => widget.onChanged((widget.hue + direction * 5) % 360),
      onActivate: widget.onTap,
      child: Semantics(
        slider: true,
        label: widget.label,
        value: '${widget.hue.round()} degrees',
        increasedValue: '${((widget.hue + 5) % 360).round()} degrees',
        decreasedValue: '${((widget.hue - 5) % 360).round()} degrees',
        onIncrease: () => widget.onChanged((widget.hue + 5) % 360),
        onDecrease: () => widget.onChanged((widget.hue - 5) % 360),
        child: MouseRegion(
          cursor: _active ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            onDoubleTap: widget.onReset,
            onPanStart: (_) {
              _cursor.show(context, SystemMouseCursors.grabbing);
              setState(() => _active = true);
              widget.onStart?.call();
            },
            onPanUpdate: (d) => widget.onChanged((widget.hue + (d.delta.dx - d.delta.dy) * 1.2) % 360),
            onPanEnd: (_) {
              _cursor.hide();
              setState(() => _active = false);
              widget.onEnd?.call();
            },
            child: Glide(
              value: widget.hue,
              instant: _active,
              builder: (hue) => CustomPaint(
                size: Size.square(widget.size),
                painter: _KnobPainter(
                  hue: hue,
                  unity: widget.unity,
                  ring: widget.ring,
                  body: widget.center ?? colors.surfaceContainerLowest,
                  ink: widget.center?.ink ?? colors.onSurface,
                  rim: widget.rim ?? colors.surfaceContainerLowest,
                  lifted: _hovered || _active,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KnobPainter({
  required final double hue,
  required final double? unity,
  required final List<Color> ring,
  required final Color body,
  required final Color ink,
  required final Color rim,
  required final bool lifted,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    Offset at(double deg, double radius) {
      final rad = (deg - 90) * math.pi / 180;
      return c + Offset(math.cos(rad), math.sin(rad)) * radius;
    }

    final step = 360 / ring.length;
    final home = unity == null ? null : (unity! / step).round() % ring.length;
    for (var i = 0; i < ring.length; i++) {
      final isHome = i == home;
      canvas.drawLine(
        at(i * step, r - (isHome ? 7.5 : 5)),
        at(i * step, r - 1),
        Paint()
          ..color = ring[i]
          ..strokeWidth = isHome ? 2.4 : 1.7
          ..strokeCap = StrokeCap.round,
      );
    }

    final capR = r - 9;
    canvas.drawCircle(
      c.translate(0, lifted ? 3 : 2),
      capR,
      Paint()
        ..color = const Color(0x38000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, lifted ? 5 : 3),
    );
    canvas.drawCircle(c, capR + 1.5, Paint()..color = rim);
    canvas.drawCircle(c, capR, Paint()..color = body);
    canvas.drawCircle(at(hue, capR * 0.62), 2.6, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_KnobPainter old) =>
      old.hue != hue ||
      old.unity != unity ||
      old.body != body ||
      old.lifted != lifted ||
      old.rim != rim ||
      !_sameColors(old.ring, ring);
}

/// A channel fader: a track that fills with color up to its cap, over a
/// printed scale. Tap to jump, drag to slide, double-tap to reset.
class const Fader({
  super.key,
  required final double value,
  required final Color Function(double t) colorAt,
  required final ValueChanged<double> onChanged,
  final double? unity,
  final VoidCallback? onStart,
  final VoidCallback? onEnd,
  final VoidCallback? onReset,

  /// Vertical faders grow upward, horizontal ones to the right.
  final Axis axis = Axis.vertical,

  /// How long a vertical fader is. A horizontal one fills its width.
  final double height = 132,

  /// The ring that sets the cap off from what's behind it.
  final Color? rim,
  final String? semanticLabel,
  final String? semanticValue,
}) extends StatefulWidget {
  @override
  State<Fader> createState() => _FaderState();
}

class _FaderState() extends State<Fader> {
  final _cursor = DragCursor();
  bool _active = false;
  bool _hovered = false;

  @override
  void dispose() {
    _cursor.hide();
    super.dispose();
  }

  static const _thickness = 40.0;

  double _valueAt(Offset p, Size size) {
    const cap = _FaderPainter.capHeight;
    final along = widget.axis == Axis.vertical
        ? 1 - (p.dy - cap / 2) / (size.height - cap)
        : (p.dx - cap / 2) / (size.width - cap);
    var v = along.clamp(0.0, 1.0);
    if (widget.unity case final u? when (v - u).abs() < 0.03) {
      if (v != u) HapticFeedback.selectionClick();
      v = u;
    }
    return v;
  }

  void _nudge(double by) => widget.onChanged((widget.value + by).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final vertical = widget.axis == Axis.vertical;
    void update(Offset p) => widget.onChanged(_valueAt(p, context.size!));
    void start(DragStartDetails d) {
      _cursor.show(context, SystemMouseCursors.grabbing);
      setState(() => _active = true);
      widget.onStart?.call();
      update(d.localPosition);
    }

    void end(DragEndDetails _) {
      _cursor.hide();
      setState(() => _active = false);
      widget.onEnd?.call();
    }

    return _KeyboardAdjustment(
      label: widget.semanticLabel ?? 'Fader',
      onStep: (direction) => _nudge(direction * 0.05),
      child: Semantics(
        slider: true,
        label: widget.semanticLabel,
        value: widget.semanticValue,
        increasedValue: '${((widget.value + 0.05).clamp(0.0, 1.0) * 100).round()}%',
        decreasedValue: '${((widget.value - 0.05).clamp(0.0, 1.0) * 100).round()}%',
        onIncrease: () => _nudge(0.05),
        onDecrease: () => _nudge(-0.05),
        child: MouseRegion(
          cursor: _active ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: widget.onReset,
            onVerticalDragStart: vertical ? start : null,
            onVerticalDragUpdate: vertical ? (d) => update(d.localPosition) : null,
            onVerticalDragEnd: vertical ? end : null,
            onHorizontalDragStart: vertical ? null : start,
            onHorizontalDragUpdate: vertical ? null : (d) => update(d.localPosition),
            onHorizontalDragEnd: vertical ? null : end,
            onTapUp: (d) {
              widget.onStart?.call();
              update(d.localPosition);
              widget.onEnd?.call();
            },
            child: SizedBox(
              height: vertical ? widget.height : _thickness,
              width: double.infinity,
              child: Glide(
                value: widget.value,
                instant: _active,
                builder: (value) => CustomPaint(
                  painter: _FaderPainter(
                    axis: widget.axis,
                    value: value,
                    unity: widget.unity,
                    range: [for (var i = 0; i < 12; i++) widget.colorAt(i / 11)],
                    capColor: widget.colorAt(value),
                    rim: widget.rim ?? colors.surfaceContainerLowest,
                    scale: colors.onSurface,
                    lifted: _active || _hovered,
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

class _FaderPainter({
  required final Axis axis,
  required final double value,
  required final double? unity,
  required final List<Color> range,
  required final Color capColor,
  required final Color rim,
  required final Color scale,
  required final bool lifted,
}) extends CustomPainter {
  static const capHeight = 18.0;
  static const _track = 10.0;

  /// Paints standing up; a horizontal fader is the same fader turned a
  /// quarter clockwise, so its bottom lands on the left.
  @override
  void paint(Canvas canvas, Size size) {
    if (axis == Axis.horizontal) {
      canvas
        ..save()
        ..translate(size.width, 0)
        ..rotate(math.pi / 2);
      _paint(canvas, size.flipped, const Offset(1, 0));
      canvas.restore();
    } else {
      _paint(canvas, size, const Offset(0, 1));
    }
  }

  /// [down] is the screen's down in the painting's own frame, for shadows.
  void _paint(Canvas canvas, Size size, Offset down) {
    final cx = size.width / 2;
    const top = capHeight / 2;
    final bottom = size.height - capHeight / 2;
    double yOf(double v) => bottom - (bottom - top) * v;

    final marks = Paint()
      ..color = scale.withValues(alpha: 0.22)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i <= 10; i++) {
      final y = yOf(i / 10);
      final long = i % 5 == 0;
      for (final side in [-1.0, 1.0]) {
        final from = cx + side * (_track / 2 + 4);
        canvas.drawLine(Offset(from, y), Offset(from + side * (long ? 5 : 3), y), marks);
      }
    }
    if (unity case final u?) {
      final y = yOf(u);
      final home = Paint()
        ..color = scale.withValues(alpha: 0.7)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (final side in [-1.0, 1.0]) {
        final from = cx + side * (_track / 2 + 4);
        canvas.drawLine(Offset(from, y), Offset(from + side * 7, y), home);
      }
    }

    final trackRect = Rect.fromLTRB(cx - _track / 2, top - _track / 2, cx + _track / 2, bottom + _track / 2);
    final track = RRect.fromRectAndRadius(trackRect, const Radius.circular(_track / 2));
    canvas.drawRRect(
      track,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [for (final c in range) c.withValues(alpha: 0.3)],
          stops: [for (var i = 0; i < range.length; i++) i / (range.length - 1)],
        ).createShader(trackRect),
    );
    final y = yOf(value);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, y, size.width, size.height));
    canvas.drawRRect(track, Paint()..color = capColor);
    canvas.restore();

    final width = math.min(size.width - 6, 34.0) + (lifted ? 2 : 0);
    final cap = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, y), width: width, height: capHeight),
      const Radius.circular(capHeight / 2),
    );
    canvas.drawRRect(
      cap.shift(down * (lifted ? 3 : 1.5)),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, lifted ? 5 : 3),
    );
    canvas.drawRRect(cap, Paint()..color = rim);
    canvas.drawRRect(cap.deflate(3), Paint()..color = capColor);
    canvas.drawLine(
      Offset(cx - 6, y),
      Offset(cx + 6, y),
      Paint()
        ..color = capColor.ink.withValues(alpha: 0.6)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_FaderPainter old) =>
      old.axis != axis ||
      old.value != value ||
      old.unity != unity ||
      old.lifted != lifted ||
      old.capColor != capColor ||
      old.rim != rim ||
      !_sameColors(old.range, range);
}

/// A knob with a ring of ticks. Drag up or right to turn it, or scroll.
class const TickKnob({
  super.key,
  required final double value,
  required final ValueChanged<double> onChanged,
  required final String label,
  required final String readout,
  final double? rest,
  final VoidCallback? onStart,
  final VoidCallback? onEnd,
  final double size = 92,
}) extends StatefulWidget {
  @override
  State<TickKnob> createState() => _TickKnobState();
}

class _TickKnobState() extends State<TickKnob> {
  final _cursor = DragCursor();
  bool _active = false;
  bool _hovered = false;
  double _drag = 0;

  @override
  void dispose() {
    _cursor.hide();
    super.dispose();
  }

  void _set(double v) {
    var next = v.clamp(0.0, 1.0);
    if (widget.rest case final rest? when (next - rest).abs() < 0.03) {
      if (widget.value != rest) HapticFeedback.selectionClick();
      next = rest;
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final changed = widget.rest != null && (widget.value - widget.rest!).abs() > 0.001;
    final capSize = widget.size - 32;

    // The ring is a scale: click a tick to jump there.
    final ring = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapUp: (d) {
          final v = _TickKnobPainter.valueAt(d.localPosition - Size.square(widget.size).center(Offset.zero));
          if (v == null) return;
          widget.onStart?.call();
          _set(v);
          widget.onEnd?.call();
        },
        child: Glide(
          value: widget.value,
          instant: _active,
          builder: (value) => CustomPaint(
            size: Size.square(widget.size),
            painter: _TickKnobPainter(
              value: value,
              rest: widget.rest,
              on: colors.primary,
              off: colors.outlineVariant,
              cap: colors.surfaceContainerLowest,
              rim: colors.surfaceContainerHighest,
              lifted: _hovered || _active,
            ),
          ),
        ),
      ),
    );

    // The cap is the handle: grab it and drag sideways or up and down.
    final cap = MouseRegion(
      cursor: _active ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.rest == null ? null : () => _set(widget.rest!),
        onPanStart: (_) {
          _drag = widget.value;
          _cursor.show(context, SystemMouseCursors.grabbing);
          setState(() => _active = true);
          widget.onStart?.call();
        },
        onPanUpdate: (d) {
          _drag = (_drag + (d.delta.dx - d.delta.dy) / 180).clamp(0.0, 1.0);
          _set(_drag);
        },
        onPanEnd: (_) {
          _cursor.hide();
          setState(() => _active = false);
          widget.onEnd?.call();
        },
        child: SizedBox.square(dimension: capSize),
      ),
    );

    return _KeyboardAdjustment(
      label: widget.label,
      onStep: (direction) => _set(widget.value + direction * 0.05),
      child: Semantics(
        slider: true,
        label: widget.label,
        value: widget.readout,
        increasedValue: 'More',
        decreasedValue: 'Less',
        onIncrease: () => _set(widget.value + 0.05),
        onDecrease: () => _set(widget.value - 0.05),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: widget.size,
              child: Stack(alignment: Alignment.center, children: [ring, cap]),
            ),
            const SizedBox(height: 8),
            Text(
              widget.readout,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: displayStyle(20, weight: FontWeight.w500, color: changed ? colors.primary : colors.onSurface),
            ),
            const SizedBox(height: 2),
            Text(widget.label, style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _TickKnobPainter({
  required final double value,
  required final double? rest,
  required final Color on,
  required final Color off,
  required final Color cap,
  required final Color rim,
  required final bool lifted,
}) extends CustomPainter {
  static const _start = -135.0;
  static const _sweep = 270.0;
  static const _ticks = 37;

  /// The value under [fromCenter], or null too close to the middle to tell.
  static double? valueAt(Offset fromCenter) {
    if (fromCenter.distance < 8) return null;
    final deg = math.atan2(fromCenter.dx, -fromCenter.dy) * 180 / math.pi;
    if (deg.abs() > -_start) return deg > 0 ? 1 : 0;
    return (deg - _start) / _sweep;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    Offset at(double deg, double radius) {
      final rad = (deg - 90) * math.pi / 180;
      return c + Offset(math.cos(rad), math.sin(rad)) * radius;
    }

    for (var i = 0; i < _ticks; i++) {
      final t = i / (_ticks - 1);
      final deg = _start + _sweep * t;
      final isRest = rest != null && (t - rest!).abs() < 0.5 / (_ticks - 1);
      final lit = t <= value + 0.0001;
      canvas.drawLine(
        at(deg, r - (isRest ? 10 : 7)),
        at(deg, r - 1),
        Paint()
          ..color = lit ? on : off
          ..strokeWidth = isRest ? 2.4 : 1.6
          ..strokeCap = StrokeCap.round,
      );
    }

    final capR = r - 16;
    canvas.drawCircle(
      c.translate(0, lifted ? 4 : 2.5),
      capR,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, lifted ? 7 : 4),
    );
    canvas.drawCircle(c, capR + 2, Paint()..color = rim);
    canvas.drawCircle(c, capR, Paint()..color = cap);
    canvas.drawCircle(at(_start + _sweep * value, capR * 0.68), 4, Paint()..color = on);
  }

  @override
  bool shouldRepaint(_TickKnobPainter old) =>
      old.value != value || old.lifted != lifted || old.on != on || old.cap != cap || old.off != off;
}

/// Asks for a color with hue, chroma, and tone sliders, or typed as hex, rgb(),
/// hsl(), or oklch().
Future<Color?> askForColor(
  BuildContext context, {
  required String title,
  required Color initial,
  String action = 'Use color',
}) {
  final hct = Hct.fromInt(initial.toARGB32());
  return showDialog<Color>(
    context: context,
    builder: (context) => _ColorDialog(title: title, action: action, hue: hct.hue, chroma: hct.chroma, tone: hct.tone),
  );
}

/// Asks for the hue and chroma of a palette, previewed at [tone], the way the
/// theme will show it. A typed color gives its hue and chroma; its tone is the
/// scheme's to pick.
Future<({double hue, double chroma})?> askForPaletteColor(
  BuildContext context, {
  required String title,
  required double hue,
  required double chroma,
  required double tone,
  String action = 'Use it',
}) {
  return showDialog<({double hue, double chroma})>(
    context: context,
    builder: (context) =>
        _ColorDialog(title: title, action: action, hue: hue, chroma: chroma, tone: tone, palette: true),
  );
}

class const _ColorDialog({
  required final String title,
  required final String action,
  required final double hue,
  required final double chroma,
  required final double tone,
  final bool palette = false,
}) extends StatefulWidget {
  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState() extends State<_ColorDialog> {
  static const _maxChroma = 120.0;
  late double _hue = widget.hue;
  late double _chroma = widget.chroma;
  late double _tone = widget.tone;
  late final _controller = TextEditingController(text: _color.hex);
  bool _valid = true;
  bool _showInputError = false;

  Color get _color => Color(Hct.from(_hue, _chroma, _tone).toInt());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _slide({double? hue, double? chroma, double? tone}) {
    setState(() {
      _hue = hue ?? _hue;
      _chroma = chroma ?? _chroma;
      _tone = tone ?? _tone;
      _valid = true;
      _showInputError = false;
      _controller.text = _color.hex;
    });
  }

  void _typed(String text) {
    final parsed = parseColor(text);
    setState(() {
      _valid = parsed != null;
      if (parsed == null) return;
      _showInputError = false;
      final typed = Hct.fromInt(parsed.toARGB32());
      _hue = typed.hue;
      _chroma = typed.chroma;
      if (!widget.palette) _tone = typed.tone;
    });
  }

  void _submit() {
    if (!_valid) {
      setState(() => _showInputError = true);
      return;
    }
    Navigator.of(context).pop(widget.palette ? (hue: _hue, chroma: _chroma) : _color);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = widget.palette;
    final swatch = _color;
    return AlertDialog(
      title: Text(widget.title, style: displayStyle(24)),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              constraints: const BoxConstraints(minHeight: 80),
              decoration: BoxDecoration(color: swatch, borderRadius: BorderRadius.circular(22)),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(
                    swatch.hex,
                    style: displayStyle(26, weight: FontWeight.w600, color: swatch.ink),
                  ),
                  Text(swatch.oklchCss, style: monoStyle(11.5, color: swatch.ink.withValues(alpha: 0.8))),
                ],
              ),
            ),
            if (palette) ...[
              const SizedBox(height: 10),
              Text(
                'Its hue and colorfulness set the whole palette. Each role keeps its own lightness, '
                'so text on it stays easy to read.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 18),
            Focus(
              canRequestFocus: false,
              onFocusChange: (focused) {
                if (!focused && !_valid) setState(() => _showInputError = true);
              },
              child: TextField(
                controller: _controller,
                style: monoStyle(16),
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Color value',
                  hintText: '#6B3BFF',
                  errorText: _showInputError ? 'Enter a hex, RGB, HSL, or OKLCH color.' : null,
                  border: const OutlineInputBorder(),
                ),
                onChanged: _typed,
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: 16),
            _SliderRow(
              label: 'Hue',
              unit: 'degrees',
              value: _hue,
              max: 360,
              onChanged: (hue) => _slide(hue: hue),
            ),
            _SliderRow(
              label: 'Chroma',
              value: _chroma,
              max: _maxChroma,
              onChanged: (chroma) => _slide(chroma: chroma),
            ),
            if (!palette)
              _SliderRow(
                label: 'Tone',
                value: _tone,
                max: 100,
                onChanged: (tone) => _slide(tone: tone),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _valid ? _submit : null, child: Text(widget.action)),
      ],
    );
  }
}

class const _SliderRow({
  required final String label,
  required final double value,
  required final double max,
  required final ValueChanged<double> onChanged,
  final String? unit,
}) extends StatefulWidget {
  @override
  State<_SliderRow> createState() => _SliderRowState();
}

class _SliderRowState() extends State<_SliderRow> {
  late final _input = TextEditingController(text: _number);
  late final _focus = FocusNode()..addListener(_syncInput);

  double get _value => widget.value.clamp(0, widget.max);
  String get _number => _value.round().toString();

  void _syncInput() {
    if (!_focus.hasFocus && _input.text != _number) _input.text = _number;
  }

  @override
  void didUpdateWidget(_SliderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncInput();
  }

  @override
  void dispose() {
    _focus.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final label = unit == null ? widget.label : '${widget.label} ($unit)';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: Semantics(
                  label: label,
                  child: Slider(
                    value: _value,
                    max: widget.max,
                    divisions: widget.max.round(),
                    semanticFormatterCallback: (value) => unit == null ? '${value.round()}' : '${value.round()} $unit',
                    onChanged: (value) {
                      if (_focus.hasFocus) _focus.unfocus();
                      widget.onChanged(value);
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 70,
                child: Semantics(
                  label: '$label value',
                  child: TextField(
                    controller: _input,
                    focusNode: _focus,
                    textAlign: TextAlign.center,
                    style: monoStyle(16),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      TextInputFormatter.withFunction((previous, next) {
                        final number = int.tryParse(next.text);
                        return next.text.isEmpty || (number != null && number <= widget.max) ? next : previous;
                      }),
                    ],
                    decoration: InputDecoration(
                      suffixText: unit == 'degrees' ? '°' : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (text) {
                      if (double.tryParse(text) case final value?) widget.onChanged(value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
