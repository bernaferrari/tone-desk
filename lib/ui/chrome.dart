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

/// A focusable Material tap target for buttons with custom artwork.
class const Pressable({
  super.key,
  required final Widget Function(BuildContext context, bool hovered, bool pressed) builder,
  required final VoidCallback? onTap,
  final String? tooltip,
  final bool? selected,
  final double pressedScale = 0.96,
}) extends StatefulWidget {
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState() extends State<Pressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final colors = Theme.of(context).colorScheme;
    final face = widget.builder(context, enabled && _hovered, enabled && _pressed);
    Widget child = Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) => setState(() => _hovered = value),
          onHighlightChanged: (value) => setState(() => _pressed = value),
          onFocusChange: (value) => setState(() => _focused = value),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: _focused ? Border.all(color: colors.primary, width: 2) : null,
            ),
            child: AnimatedScale(
              scale: _pressed ? widget.pressedScale : 1,
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: face,
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip case final tip?) child = Tooltip(message: tip, child: child);
    return child;
  }
}

/// Round Material icon button in the studio's ink.
class const StudioIconButton({
  super.key,
  required final IconData icon,
  required final String tooltip,
  required final VoidCallback? onTap,
  final bool? selected,
  final Color? ink,
  final double size = 40,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = selected == true;
    final buttonInk = ink ?? colors.onSurface;
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      isSelected: selected,
      onPressed: onTap,
      style: IconButton.styleFrom(
        foregroundColor: active ? (ink?.ink ?? colors.onPrimary) : buttonInk,
        backgroundColor: active ? (ink ?? colors.primary) : null,
        minimumSize: Size.square(size),
        iconSize: size * 0.48,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.standard,
      ),
    );
  }
}

/// Standard Material buttons with the studio's compact sizing.
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
    final style = FilledButton.styleFrom(
      minimumSize: Size(0, dense ? 32 : 40),
      padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16),
      iconSize: dense ? 15 : 17,
    );
    final leading = icon == null ? null : Icon(icon);
    final text = Text(label);
    final child = filled
        ? FilledButton.icon(onPressed: onTap, style: style, icon: leading, label: text)
        : FilledButton.tonalIcon(onPressed: onTap, style: style, icon: leading, label: text);
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

/// The Tone Desk mark: four faders, as on the original Color Studio icon.
class const FaderMark({super.key, final double size = 36, final Color? background, final Color? ink})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: CustomPaint(
        size: Size.square(size),
        painter: _FaderMarkPainter(background ?? colors.primary, ink ?? colors.onPrimary),
      ),
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
