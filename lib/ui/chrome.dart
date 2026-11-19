import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../model/color_math.dart';

const phoneBreakpoint = 720.0;
const deskBreakpoint = 1180.0;

bool _fetch() => GoogleFonts.config.allowRuntimeFetching;

/// Text measured before its font arrives keeps the wrong width, so the studio
/// waits briefly for the faces it uses most.
Future<void> preloadFonts() async {
  if (!_fetch()) return;
  for (final weight in [FontWeight.w400, FontWeight.w500, FontWeight.w600, FontWeight.w700]) {
    GoogleFonts.geist(fontWeight: weight);
  }
  GoogleFonts.geistMono(fontWeight: FontWeight.w500);
  GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w600);
  try {
    await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 3));
  } on Object catch (_) {}
}

TextStyle displayStyle(double size, {Color? color, FontWeight weight = FontWeight.w600, double height = 1}) {
  final style = TextStyle(
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: -size * 0.035,
    color: color,
  );
  return _fetch() ? GoogleFonts.bricolageGrotesque(textStyle: style) : style;
}

TextStyle monoStyle(double size, {Color? color, FontWeight weight = FontWeight.w500, double? letterSpacing}) {
  final style = TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  return _fetch() ? GoogleFonts.geistMono(textStyle: style) : style.copyWith(fontFamily: 'monospace');
}

/// Small uppercase label, like the silk-screen on a mixing desk.
TextStyle legendStyle(BuildContext context, {Color? color}) => monoStyle(
  10.5,
  weight: FontWeight.w600,
  letterSpacing: 1.1,
  color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
);

/// The studio dresses itself in the theme being made.
ThemeData studioTheme(ColorScheme colors) {
  final base = ThemeData(useMaterial3: true, colorScheme: colors, brightness: colors.brightness);
  final text = _fetch() ? GoogleFonts.geistTextTheme(base.textTheme) : base.textTheme;
  return base.copyWith(
    textTheme: text.apply(bodyColor: colors.onSurface, displayColor: colors.onSurface),
    scaffoldBackgroundColor: colors.surface,
    splashFactory: InkSparkle.splashFactory,
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450),
      decoration: BoxDecoration(color: colors.inverseSurface, borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(color: colors.onInverseSurface, fontSize: 12, fontWeight: FontWeight.w500),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.inverseSurface,
      contentTextStyle: TextStyle(color: colors.onInverseSurface, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      width: 360,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(colors.onSurface.withValues(alpha: 0.18)),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(6),
    ),
  );
}

/// Theme for mock app screens: Material defaults, nothing studio-specific.
ThemeData previewTheme(ColorScheme colors) {
  final base = ThemeData(useMaterial3: true, colorScheme: colors, brightness: colors.brightness);
  final text = _fetch() ? GoogleFonts.geistTextTheme(base.textTheme) : base.textTheme;
  return base.copyWith(
    textTheme: text.apply(bodyColor: colors.onSurface, displayColor: colors.onSurface),
    splashFactory: InkSparkle.splashFactory,
  );
}

Future<void> copyText(BuildContext context, String text, {String? label}) async {
  HapticFeedback.selectionClick();
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('Copied ${label ?? text}'), duration: const Duration(milliseconds: 1400)));
}

/// Hover and press feedback for anything tappable.
class const Pressable({
  super.key,
  required final Widget Function(BuildContext context, bool hovered, bool pressed) builder,
  required final VoidCallback? onTap,
  final VoidCallback? onDoubleTap,
  final String? tooltip,
  final String? semanticLabel,
  final double pressedScale = 0.96,
}) extends StatefulWidget {
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState() extends State<Pressable> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    Widget child = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: widget.builder(context, _hovered && enabled, _pressed),
        ),
      ),
    );
    child = Semantics(button: true, enabled: enabled, label: widget.semanticLabel, child: child);
    if (widget.tooltip case final tip?) child = Tooltip(message: tip, child: child);
    return child;
  }
}

/// Round icon button in the studio's ink.
class const StudioIconButton({
  super.key,
  required final IconData icon,
  required final String tooltip,
  required final VoidCallback? onTap,
  final bool selected = false,
  final Color? ink,
  final double size = 40,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ink = this.ink ?? colors.onSurface;
    return Pressable(
      tooltip: tooltip,
      onTap: onTap,
      pressedScale: 0.9,
      builder: (context, hovered, pressed) {
        final fill = selected
            ? (this.ink == null ? colors.primary : ink)
            : ink.withValues(alpha: onTap == null ? 0 : (pressed ? 0.16 : (hovered ? 0.1 : 0.0)));
        final iconColor = selected
            ? (this.ink == null ? colors.onPrimary : ink.ink)
            : ink.withValues(alpha: onTap == null ? 0.28 : 0.9);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: size,
          height: size,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          child: Icon(icon, size: size * 0.48, color: iconColor),
        );
      },
    );
  }
}

/// Pill button with a label and optional icon.
class const PillButton({
  super.key,
  required final String label,
  required final VoidCallback? onTap,
  final IconData? icon,
  final bool filled = false,
  final String? tooltip,
  final bool dense = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Pressable(
      tooltip: tooltip,
      onTap: onTap,
      builder: (context, hovered, pressed) {
        final bg = filled
            ? colors.primary
            : Color.alphaBlend(colors.onSurface.withValues(alpha: hovered ? 0.06 : 0), colors.surfaceContainerHighest);
        final fg = filled ? colors.onPrimary : colors.onSurface;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: dense ? 32 : 40,
          padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16),
          decoration: BoxDecoration(
            color: filled && hovered ? Color.alphaBlend(fg.withValues(alpha: 0.08), bg) : bg,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: dense ? 15 : 17, color: fg), SizedBox(width: dense ? 6 : 8)],
              Text(
                label,
                style: TextStyle(color: fg, fontSize: dense ? 12.5 : 13.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A segmented control with a sliding thumb.
class const Segmented<T>({
  super.key,
  required final T value,
  required final List<T> values,
  required final String Function(T) label,
  required final ValueChanged<T> onChanged,
  final IconData Function(T)? icon,
  final double height = 40,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final index = values.indexOf(value);
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(99)),
      child: IntrinsicWidth(
        child: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth / values.length;
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutBack,
                        left: w * index,
                        width: w,
                        top: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [
                              BoxShadow(
                                color: colors.shadow.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Row(
              children: [
                for (final v in values)
                  Expanded(
                    child: Pressable(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onChanged(v);
                      },
                      pressedScale: 0.94,
                      builder: (context, hovered, pressed) {
                        final selected = v == value;
                        final fg = selected ? colors.onSurface : colors.onSurfaceVariant;
                        return Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon != null) ...[Icon(icon!(v), size: 15, color: fg), const SizedBox(width: 6)],
                              Text(
                                label(v),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: fg,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The Tone Desk mark: four faders, as on the original Color Studio icon.
class const FaderMark({super.key, final double size = 36, final Color? background, final Color? ink})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size.square(size),
      painter: _FaderMarkPainter(background ?? colors.primary, ink ?? colors.onPrimary),
    );
  }
}

class _FaderMarkPainter(final Color background, final Color ink) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.26)),
      Paint()..color = background,
    );
    // The app icon's faders (docs/brand/foreground.svg), in the theme's colors.
    const caps = [0.583, 0.278, 0.472, 0.347];
    final bar = s * 0.097;
    final (top, bottom) = (s * 0.181, s * 0.819);
    final track = Paint()..color = ink.withValues(alpha: 0.32);
    final fill = Paint()..color = ink;
    final rim = Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03;
    for (var i = 0; i < 4; i++) {
      final x = s * (0.208 + i * 0.1945);
      final cap = s * caps[i];
      final round = Radius.circular(bar / 2);
      canvas.drawRRect(RRect.fromLTRBR(x - bar / 2, top, x + bar / 2, bottom, round), track);
      canvas.drawRRect(RRect.fromLTRBR(x - bar / 2, cap, x + bar / 2, bottom, round), fill);
      final knob = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, cap), width: s * 0.18, height: bar),
        round,
      );
      canvas.drawRRect(knob, fill);
      canvas.drawRRect(knob, rim);
    }
  }

  @override
  bool shouldRepaint(_FaderMarkPainter old) => old.background != background || old.ink != ink;
}

/// A rounded panel on the studio floor.
class const Panel({
  super.key,
  required final Widget child,
  final EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  final Color? color,
  final double radius = 28,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}
