import 'dart:math' as math;

import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

/// OKLCH, the cylindrical form of Björn Ottosson's OKLab.
@immutable
class const Oklch(
  final double l, // 0 .. 1
  final double c, // 0 .. ~0.37
  final double h, // 0 .. 360
) {
  factory fromColor(Color color) {
    final r = _toLinear(color.r);
    final g = _toLinear(color.g);
    final b = _toLinear(color.b);

    final l_ = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    final m_ = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    final s_ = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);

    final okL = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_;
    final okA = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_;
    final okB = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_;

    var hue = math.atan2(okB, okA) * 180 / math.pi;
    if (hue < 0) hue += 360;
    return Oklch(okL.clamp(0.0, 1.0), math.sqrt(okA * okA + okB * okB), hue);
  }

  /// Gamut-maps by reducing chroma, so the hue never drifts.
  Color toColor() {
    final safeC = math.min(c, maxChroma(l, h));
    final (r, g, b) = _toLinearSrgb(l, safeC, h);
    return Color.from(
      alpha: 1,
      red: _toGamma(r.clamp(0.0, 1.0)),
      green: _toGamma(g.clamp(0.0, 1.0)),
      blue: _toGamma(b.clamp(0.0, 1.0)),
    );
  }

  String toCss() {
    // Achromatic colors carry no meaningful hue.
    final hue = c < 0.0005 ? 0.0 : h;
    return 'oklch(${_trim(l * 100, 1)}% ${_trim(c, 3)} ${_trim(hue, 1)})';
  }

  static double maxChroma(double l, double h) {
    if (l <= 0.0005 || l >= 0.9995) return 0;
    var low = 0.0;
    var high = 0.37;
    for (var i = 0; i < 16; i++) {
      final mid = (low + high) / 2;
      final (r, g, b) = _toLinearSrgb(l, mid, h);
      const eps = 1e-4;
      final inside = r >= -eps && r <= 1 + eps && g >= -eps && g <= 1 + eps && b >= -eps && b <= 1 + eps;
      if (inside) {
        low = mid;
      } else {
        high = mid;
      }
    }
    return low;
  }

  static (double, double, double) _toLinearSrgb(double l, double c, double h) {
    final rad = h * math.pi / 180;
    final a = c * math.cos(rad);
    final b = c * math.sin(rad);
    final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = l - 0.0894841775 * a - 1.2914855480 * b;
    final l3 = l_ * l_ * l_;
    final m3 = m_ * m_ * m_;
    final s3 = s_ * s_ * s_;
    return (
      4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
      -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
      -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3,
    );
  }

  static double _toLinear(double c) => c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  static double _toGamma(double c) => c <= 0.0031308 ? 12.92 * c : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;

  static double _cbrt(double x) => x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();
}

String _trim(double value, int digits) {
  var text = value.toStringAsFixed(digits);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return text == '-0' ? '0' : text;
}

extension ColorText on Color {
  String get hex => '#${toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  String get hexBare => hex.substring(1);

  String get dartLiteral => 'Color(0xFF$hexBare)';

  String get oklchCss => Oklch.fromColor(this).toCss();

  Hct get hct => Hct.fromInt(toARGB32());

  int get tone => hct.tone.round();

  /// Ink that reads on top of this color.
  Color get ink => computeLuminance() > 0.36 ? const Color(0xFF111114) : Colors.white;
}

/// WCAG 2 contrast ratio.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Parses hex (`#RGB`, `#RRGGBB`), `rgb()`, `hsl()`, and `oklch()`.
Color? parseColor(String raw) {
  final input = raw.trim().toLowerCase();
  if (input.isEmpty) return null;

  final hex = RegExp(r'^#?([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$').firstMatch(input);
  if (hex != null) {
    var digits = hex.group(1)!;
    if (digits.length == 3) digits = digits.split('').map((d) => '$d$d').join();
    if (digits.length == 8) digits = digits.substring(0, 6);
    return Color(int.parse('FF$digits', radix: 16));
  }

  final number = r'(-?[\d.]+)';
  final sep = r'\s*[,\s]\s*';

  final rgb = RegExp('^rgba?\\(\\s*$number$sep$number$sep$number').firstMatch(input);
  if (rgb != null) {
    int channel(int i) => double.parse(rgb.group(i)!).round().clamp(0, 255);
    return Color.fromARGB(255, channel(1), channel(2), channel(3));
  }

  final hsl = RegExp('^hsla?\\(\\s*$number(?:deg)?$sep$number%?$sep$number%?').firstMatch(input);
  if (hsl != null) {
    final h = double.parse(hsl.group(1)!) % 360;
    final s = (double.parse(hsl.group(2)!) / 100).clamp(0.0, 1.0);
    final l = (double.parse(hsl.group(3)!) / 100).clamp(0.0, 1.0);
    return HSLColor.fromAHSL(1, h, s, l).toColor();
  }

  final oklch = RegExp('^oklch\\(\\s*$number(%?)\\s+$number\\s+$number').firstMatch(input);
  if (oklch != null) {
    var l = double.parse(oklch.group(1)!);
    if (oklch.group(2) == '%' || l > 1) l /= 100;
    return Oklch(
      l.clamp(0.0, 1.0),
      double.parse(oklch.group(3)!).clamp(0.0, 0.37),
      double.parse(oklch.group(4)!) % 360,
    ).toColor();
  }
  return null;
}

/// A vivid, never-muddy seed for shuffling.
Color randomSeed(math.Random rng) {
  final hue = rng.nextDouble() * 360;
  // Yellows and greens need more tone to stay clean.
  final yellowish = hue > 60 && hue < 140;
  final tone = yellowish ? 62 + rng.nextDouble() * 14 : 42 + rng.nextDouble() * 20;
  final chroma = 40 + rng.nextDouble() * 50;
  return Color(Hct.from(hue, chroma, tone).toInt());
}
