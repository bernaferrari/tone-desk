import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

import '../model/color_math.dart';
import 'chrome.dart';
import 'reel.dart';

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

/// A horizontal slider whose track is a gradient sampled along its range,
/// with a lens showing the color under it. Tap to jump, drag to slide,
/// double-tap to reset.
class const BandSlider({
  super.key,
  required final double value,
  required final Color Function(double t) colorAt,
  required final ValueChanged<double> onChanged,
  final double? unity,
  final VoidCallback? onStart,
  final VoidCallback? onEnd,
  final VoidCallback? onReset,
  final double height = 28,

  /// How many colors to sample along the track's gradient.
  final int? bands,
  final String? semanticLabel,
  final String? semanticValue,
}) extends StatefulWidget {
  @override
  State<BandSlider> createState() => _BandSliderState();
}

class _BandSliderState() extends State<BandSlider> {
  final _cursor = DragCursor();
  bool _active = false;
  bool _hovered = false;
  static const _lens = 18.0;

  @override
  void dispose() {
    _cursor.hide();
    super.dispose();
  }

  double _valueAt(double dx, double width) {
    var v = ((dx - _lens / 2) / (width - _lens)).clamp(0.0, 1.0);
    if (widget.unity case final u? when (v - u).abs() < 0.02) {
      if (v != u) HapticFeedback.selectionClick();
      v = u;
    }
    return v;
  }

  void _nudge(double by) => widget.onChanged((widget.value + by).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: widget.semanticValue,
      increasedValue: '${((widget.value + 0.05).clamp(0.0, 1.0) * 100).round()}%',
      decreasedValue: '${((widget.value - 0.05).clamp(0.0, 1.0) * 100).round()}%',
      onIncrease: () => _nudge(0.05),
      onDecrease: () => _nudge(-0.05),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final count = widget.bands ?? 24;
          final bands = [for (var i = 0; i < count; i++) widget.colorAt(i / (count - 1))];
          void update(Offset p) => widget.onChanged(_valueAt(p.dx, w));
          return MouseRegion(
            cursor: _active ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: widget.onReset,
              onHorizontalDragStart: (d) {
                _cursor.show(context, SystemMouseCursors.grabbing);
                setState(() => _active = true);
                widget.onStart?.call();
                update(d.localPosition);
              },
              onHorizontalDragUpdate: (d) => update(d.localPosition),
              onHorizontalDragEnd: (_) {
                _cursor.hide();
                setState(() => _active = false);
                widget.onEnd?.call();
              },
              onTapUp: (d) {
                widget.onStart?.call();
                update(d.localPosition);
                widget.onEnd?.call();
              },
              child: SizedBox(
                height: widget.height + 10,
                child: Glide(
                  value: widget.value,
                  instant: _active,
                  builder: (value) => CustomPaint(
                    size: Size.infinite,
                    painter: _BandPainter(
                      value: value,
                      unity: widget.unity,
                      bands: bands,
                      lensColor: widget.colorAt(value),
                      rim: colors.surfaceContainerLowest,
                      tick: colors.onSurface,
                      lifted: _active || _hovered,
                      track: widget.height,
                      lens: _lens,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BandPainter({
  required final double value,
  required final double? unity,
  required final List<Color> bands,
  required final Color lensColor,
  required final Color rim,
  required final Color tick,
  required final bool lifted,
  required final double track,
  required final double lens,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final top = (size.height - track) / 2;
    final trackRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, top, size.width, track), Radius.circular(track / 2));
    canvas.drawRRect(
      trackRect,
      Paint()
        ..shader = LinearGradient(
          colors: bands,
          stops: [for (var i = 0; i < bands.length; i++) bands.length == 1 ? 0 : i / (bands.length - 1)],
        ).createShader(trackRect.outerRect),
    );

    double xOf(double v) => lens / 2 + (size.width - lens) * v;
    if (unity case final u?) {
      final x = xOf(u);
      canvas.drawLine(
        Offset(x, top + track * 0.3),
        Offset(x, top + track * 0.7),
        Paint()
          ..color = tick.withValues(alpha: 0.55)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    final lensRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(xOf(value), size.height / 2), width: lens + (lifted ? 2 : 0), height: size.height),
      const Radius.circular(9),
    );
    canvas.drawRRect(
      lensRect.shift(Offset(0, lifted ? 3 : 1.5)),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, lifted ? 5 : 3),
    );
    canvas.drawRRect(lensRect, Paint()..color = rim);
    canvas.drawRRect(lensRect.deflate(3), Paint()..color = lensColor);
  }

  @override
  bool shouldRepaint(_BandPainter old) =>
      old.value != value ||
      old.unity != unity ||
      old.lifted != lifted ||
      old.lensColor != lensColor ||
      !_sameColors(old.bands, bands);
}

bool _sameColors(List<Color> a, List<Color> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A rotary hue knob. Drag it sideways or up and down.
class const HueKnob({
  super.key,
  required final double hue,
  required final List<Color> ring,
  required final ValueChanged<double> onChanged,
  final double? unity,
  final VoidCallback? onStart,
  final VoidCallback? onEnd,
  final VoidCallback? onReset,
  final double size = 52,
  final Color? center,
  final VoidCallback? onTap,
}) extends StatefulWidget {
  @override
  State<HueKnob> createState() => _HueKnobState();
}

class _HueKnobState() extends State<HueKnob> {
  final _cursor = DragCursor();
  bool _active = false;

  @override
  void dispose() {
    _cursor.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      slider: true,
      label: 'Hue',
      value: '${widget.hue.round()} degrees',
      increasedValue: '${((widget.hue + 5) % 360).round()} degrees',
      decreasedValue: '${((widget.hue - 5) % 360).round()} degrees',
      onIncrease: () => widget.onChanged((widget.hue + 5) % 360),
      onDecrease: () => widget.onChanged((widget.hue - 5) % 360),
      child: MouseRegion(
        cursor: _active ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
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
                tick: colors.onSurfaceVariant,
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
  required final Color tick,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final ringRect = Rect.fromCircle(center: c, radius: r - 3);
    canvas.drawCircle(
      c,
      r - 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..shader = SweepGradient(
          colors: [...ring, ring.first],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(ringRect),
    );
    canvas.drawCircle(
      c.translate(0, 1.5),
      r - 9,
      Paint()
        ..color = const Color(0x2A000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(c, r - 9, Paint()..color = body);

    Offset at(double deg, double radius) {
      final rad = (deg - 90) * math.pi / 180;
      return c + Offset(math.cos(rad), math.sin(rad)) * radius;
    }

    if (unity != null) {
      canvas.drawCircle(at(unity!, r - 3), 2, Paint()..color = tick);
    }
    canvas.drawLine(
      at(hue, r * 0.18),
      at(hue, r - 13),
      Paint()
        ..color = ink
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_KnobPainter old) =>
      old.hue != hue || old.unity != unity || old.body != body || !_sameColors(old.ring, ring);
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

    return Semantics(
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
          AnimatedScale(
            scale: _active ? 1.04 : 1,
            duration: const Duration(milliseconds: 160),
            child: SizedBox.square(
              dimension: widget.size,
              child: Stack(alignment: Alignment.center, children: [ring, cap]),
            ),
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
  return showDialog<Color>(
    context: context,
    builder: (context) => _ColorDialog(title: title, initial: initial, action: action),
  );
}

class const _ColorDialog({required final String title, required final Color initial, required final String action})
    extends StatefulWidget {
  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState() extends State<_ColorDialog> {
  static const _maxChroma = 120.0;
  late final _controller = TextEditingController(text: widget.initial.hex);
  late Hct _hct = Hct.fromInt(widget.initial.toARGB32());
  late double _hue = _hct.hue;
  late double _chroma = _hct.chroma;
  late double _tone = _hct.tone;
  bool _valid = true;

  Color get _color => Color(_hct.toInt());

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
      _hct = Hct.from(_hue, _chroma, _tone);
      _valid = true;
      _controller.text = _color.hex;
    });
  }

  void _typed(String text) {
    final parsed = parseColor(text);
    setState(() {
      _valid = parsed != null;
      if (parsed == null) return;
      _hct = Hct.fromInt(parsed.toARGB32());
      _hue = _hct.hue;
      _chroma = _hct.chroma;
      _tone = _hct.tone;
    });
  }

  void _submit() {
    if (_valid) Navigator.of(context).pop(_color);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final swatch = _color;
    final hueChroma = math.max(_chroma, 24.0);
    return AlertDialog(
      title: Text(widget.title, style: displayStyle(24)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: 104,
              decoration: BoxDecoration(color: swatch, borderRadius: BorderRadius.circular(22)),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    swatch.hex,
                    style: displayStyle(26, weight: FontWeight.w600, color: swatch.ink),
                  ),
                  const Spacer(),
                  Text(swatch.oklchCss, style: monoStyle(11.5, color: swatch.ink.withValues(alpha: 0.8))),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SliderRow(
              label: 'Hue',
              readout: '${_hct.hue.round()}°',
              child: ColorReel(
                value: _hue,
                min: 0,
                max: 360,
                step: 15,
                wraps: true,
                lensColor: swatch,
                paletteKey: (hueChroma.round(), _tone.round()),
                colorAt: (h) => Color(Hct.from(h % 360, hueChroma, _tone).toInt()),
                semanticLabel: 'Hue',
                semanticValue: '${_hct.hue.round()} degrees',
                onChanged: (h) => _slide(hue: h % 360),
              ),
            ),
            _SliderRow(
              label: 'Chroma',
              readout: _hct.chroma.round().toString(),
              child: ColorReel(
                value: _chroma.clamp(0.0, _maxChroma),
                min: 0,
                max: _maxChroma,
                step: 5,
                lensColor: swatch,
                paletteKey: (_hue.round(), _tone.round()),
                colorAt: (c) => Color(Hct.from(_hue, c, _tone).toInt()),
                semanticLabel: 'Chroma',
                semanticValue: _hct.chroma.round().toString(),
                onChanged: (c) => _slide(chroma: c),
              ),
            ),
            _SliderRow(
              label: 'Tone',
              readout: _hct.tone.round().toString(),
              child: ColorReel(
                value: _tone,
                min: 0,
                max: 100,
                step: 5,
                lensColor: swatch,
                paletteKey: (_hue.round(), _chroma.round()),
                colorAt: (t) => Color(Hct.from(_hue, _chroma, t).toInt()),
                semanticLabel: 'Tone',
                semanticValue: _hct.tone.round().toString(),
                onChanged: (t) => _slide(tone: t),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              style: monoStyle(15),
              decoration: InputDecoration(
                isDense: true,
                hintText: '#6B3BFF · oklch(55% 0.25 285)',
                errorText: _valid ? null : 'Try a hex, rgb(), hsl(), or oklch() value',
                prefixIcon: Icon(Icons.tag_rounded, size: 18, color: colors.onSurfaceVariant),
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onChanged: _typed,
              onSubmitted: (_) => _submit(),
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

class const _SliderRow({required final String label, required final String readout, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface),
              ),
              const Spacer(),
              Text(readout, style: monoStyle(12, color: colors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// chroma-folio's reel, lying down: drag or fling the strip of colors and the
/// one that lands in the lens becomes the value. Tap a band to glide to it.
class const ColorReel({
  super.key,
  required final double value,
  required final double min,
  required final double max,
  required final double step,
  required final Color lensColor,
  required final Color Function(double value) colorAt,

  /// Changes whenever [colorAt] would return different colors.
  required final Object paletteKey,
  required final ValueChanged<double> onChanged,
  final bool wraps = false,
  final VoidCallback? onStart,
  final VoidCallback? onEnd,
  final double height = 52,
  final String? semanticLabel,
  final String? semanticValue,
}) extends StatefulWidget {
  @override
  State<ColorReel> createState() => _ColorReelState();
}

class _ColorReelState() extends State<ColorReel> with SingleTickerProviderStateMixin {
  static const _bandLength = 30.0;
  static const _lensInset = 6.0;
  static const _lensOverhang = 6.0;

  late final _motion = ReelMotion(
    vsync: this,
    onStart: () => widget.onStart?.call(),
    onChanged: (value) => widget.onChanged(value),
    onEnd: () => widget.onEnd?.call(),
  );
  bool _pressed = false;

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    _motion
      ..min = widget.min
      ..max = widget.max
      ..wraps = widget.wraps
      ..step = widget.step
      ..sync(widget.value);

    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: widget.semanticValue,
      increasedValue: '${(widget.value + widget.step).round()}',
      decreasedValue: '${(widget.value - widget.step).round()}',
      onIncrease: () => _motion.nudge(widget.step),
      onDecrease: () => _motion.nudge(-widget.step),
      child: Container(
        height: widget.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(22)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final band = math.min(_bandLength, constraints.maxWidth / 7);
            _motion.pixelsPerUnit = band / widget.step;
            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: ReelSurface(
                    motion: _motion,
                    axis: Axis.horizontal,
                    onPressedChanged: (pressed) => setState(() => _pressed = pressed),
                    child: CustomPaint(
                      painter: ReelStripPainter(
                        motion: _motion,
                        axis: Axis.horizontal,
                        paletteKey: (widget.paletteKey, band),
                        colorAt: widget.colorAt,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: _lensInset,
                  bottom: _lensInset,
                  width: band + _lensOverhang * 2,
                  child: ListenableBuilder(
                    listenable: _motion,
                    builder: (context, _) =>
                        ReelLens(color: widget.lensColor, pressed: _pressed, push: Offset(_motion.overshoot, 0)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
