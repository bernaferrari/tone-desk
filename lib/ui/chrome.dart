import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../model/color_math.dart';

/// Live [ColorScheme] for studio chrome while scrubbing, avoiding a full-tree
/// [MaterialApp] theme rebuild on every drag frame.
class const LiveColorsScope({
  super.key,
  required final ValueNotifier<ColorScheme> colors,
  required super.child,
}) extends InheritedWidget {
  static ValueListenable<ColorScheme>? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LiveColorsScope>()?.colors;

  static void preview(BuildContext context, ColorScheme scheme) {
    final notifier = context.getInheritedWidgetOfExactType<LiveColorsScope>()?.colors;
    if (notifier != null && notifier.value != scheme) notifier.value = scheme;
  }

  @override
  bool updateShouldNotify(LiveColorsScope old) => old.colors != colors;
}

/// Rebuilds only its own small subtree when the live studio [ColorScheme]
/// changes during a scrub.
class const LiveColors({
  super.key,
  required final Widget Function(BuildContext context, ColorScheme colors, Widget? child) builder,
  final Widget? child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final live = LiveColorsScope.maybeOf(context);
    if (live == null) return builder(context, Theme.of(context).colorScheme, child);
    return ValueListenableBuilder<ColorScheme>(valueListenable: live, builder: builder, child: child);
  }
}

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

final _displayFonts = <(FontWeight, bool), TextStyle>{};
final _monoFonts = <(FontWeight, bool), TextStyle>{};

TextStyle displayStyle(double size, {Color? color, FontWeight weight = FontWeight.w600, double height = 1}) {
  final fetch = _fetch();
  final base = _displayFonts.putIfAbsent(
    (weight, fetch),
    () => fetch ? GoogleFonts.bricolageGrotesque(fontWeight: weight) : TextStyle(fontWeight: weight),
  );
  return base.copyWith(fontSize: size, height: height, letterSpacing: -size * 0.035, color: color);
}

TextStyle monoStyle(double size, {Color? color, FontWeight weight = FontWeight.w500, double? letterSpacing}) {
  final fetch = _fetch();
  final base = _monoFonts.putIfAbsent(
    (weight, fetch),
    () => fetch
        ? GoogleFonts.geistMono(fontWeight: weight)
        : TextStyle(fontFamily: 'monospace', fontWeight: weight),
  );
  return base.copyWith(
    fontSize: size,
    color: color,
    letterSpacing: letterSpacing,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Small uppercase label, like the silk-screen on a mixing desk.
TextStyle legendStyle(BuildContext context, {Color? color}) => monoStyle(
  10.5,
  weight: FontWeight.w600,
  letterSpacing: 1.1,
  color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
);

final _geistTextThemes = <(Brightness, bool), TextTheme>{};

TextTheme _geistBaseTextTheme(ThemeData base) {
  final fetch = _fetch();
  return _geistTextThemes.putIfAbsent(
    (base.brightness, fetch),
    () => fetch ? GoogleFonts.geistTextTheme(base.textTheme) : base.textTheme,
  );
}

/// The studio dresses itself in the theme being made.
ThemeData studioTheme(ColorScheme colors) {
  final base = ThemeData(useMaterial3: true, colorScheme: colors, brightness: colors.brightness);
  final text = _geistBaseTextTheme(base);
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

final _previewBaseThemes = <(Brightness, bool), ThemeData>{};
final _previewTextThemes = <(Brightness, Color, bool), TextTheme>{};

/// Theme for mock app screens: Material defaults, nothing studio-specific.
ThemeData previewTheme(ColorScheme colors) {
  final fetch = _fetch();
  final base = _previewBaseThemes.putIfAbsent(
    (colors.brightness, fetch),
    () => ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      splashFactory: InkSparkle.splashFactory,
    ),
  );
  final text = _previewTextThemes.putIfAbsent(
    (colors.brightness, colors.onSurface, fetch),
    () => _geistBaseTextTheme(base).apply(bodyColor: colors.onSurface, displayColor: colors.onSurface),
  );
  if (_previewTextThemes.length > 64) _previewTextThemes.remove(_previewTextThemes.keys.first);
  return base.copyWith(colorScheme: colors, textTheme: text);
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
    final leading = icon == null ? null : Icon(icon);
    final text = Text(label);
    final button = RepaintBoundary(
      child: LiveColors(
        builder: (context, colors, _) {
          final style = FilledButton.styleFrom(
            minimumSize: Size(0, dense ? 36 : 40),
            padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 16),
            iconSize: dense ? 16 : 18,
            visualDensity: VisualDensity.standard,
            backgroundColor: filled ? colors.primary : colors.secondaryContainer,
            foregroundColor: filled ? colors.onPrimary : colors.onSecondaryContainer,
          );
          return filled
              ? FilledButton.icon(onPressed: onTap, style: style, icon: leading, label: text)
              : FilledButton.tonalIcon(onPressed: onTap, style: style, icon: leading, label: text);
        },
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// The Tone Desk mark: four faders, as on the original Color Studio icon.
class const FaderMark({super.key, final double size = 36, final Color? background, final Color? ink})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final live = background == null || ink == null ? LiveColorsScope.maybeOf(context) : null;
    final colors = live?.value ?? Theme.of(context).colorScheme;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: CustomPaint(
        size: Size.square(size),
        painter: _FaderMarkPainter(background, ink, colors, live),
      ),
    );
  }
}

class _FaderMarkPainter(
  final Color? background,
  final Color? ink,
  final ColorScheme fallback,
  final ValueListenable<ColorScheme>? live,
) extends CustomPainter {
  this : super(repaint: live);

  @override
  void paint(Canvas canvas, Size size) {
    final colors = live?.value ?? fallback;
    final bg = background ?? colors.primary;
    final fg = ink ?? colors.onPrimary;
    final s = size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.26)),
      Paint()..color = bg,
    );
    // The app icon's faders (docs/brand/foreground.svg), in the theme's colors.
    const caps = [0.583, 0.278, 0.472, 0.347];
    final bar = s * 0.097;
    final (top, bottom) = (s * 0.181, s * 0.819);
    final track = Paint()..color = fg.withValues(alpha: 0.32);
    final fill = Paint()..color = fg;
    final rim = Paint()
      ..color = bg
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
  bool shouldRepaint(_FaderMarkPainter old) =>
      old.background != background || old.ink != ink || old.live != live || (live == null && old.fallback != fallback);
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
    final borderRadius = BorderRadius.circular(radius);
    if (color != null) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: borderRadius),
        child: child,
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: LiveColors(
              builder: (context, colors, _) => DecoratedBox(
                decoration: BoxDecoration(color: colors.surfaceContainerLow, borderRadius: borderRadius),
              ),
            ),
          ),
        ),
        RepaintBoundary(
          child: Padding(padding: padding, child: child),
        ),
      ],
    );
  }
}
