import 'package:equatable/equatable.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

import 'color_math.dart';

/// One tonal palette of a Material 3 scheme, mixed like a channel on a desk.
/// Material's six tonal palettes. [label] is what the studio calls them;
/// [spec] is Material's own name.
enum Channel(final String label, final String spec, final double maxChroma) {
  primary('Primary', 'primary', 120),
  secondary('Secondary', 'secondary', 120),
  tertiary('Tertiary', 'tertiary', 120),
  neutral('Surfaces', 'neutral', 40),
  neutralVariant('Outlines', 'neutral variant', 40),
  error('Error', 'error', 120);

  String get key => name;
}

/// How a channel departs from what the style would generate.
///
/// Null [hue] or [chroma] means "unity": the style's own value. [chroma] is
/// stored as it would be at a scale of 1, so Vivid and Surface tint keep
/// scaling a mixed palette just like the style's own.
@immutable
class const ChannelMix({final double? hue, final double? chroma, final bool muted = false}) extends Equatable {
  static const unity = ChannelMix();

  bool get isUnity => hue == null && chroma == null && !muted;

  ChannelMix withHue(double? value) => ChannelMix(hue: value, chroma: chroma, muted: muted);

  ChannelMix withChroma(double? value) => ChannelMix(hue: hue, chroma: value, muted: muted);

  ChannelMix withMuted(bool value) => ChannelMix(hue: hue, chroma: chroma, muted: value);

  Map<String, Object?> toJson() => {
    if (hue != null) 'hue': hue,
    if (chroma != null) 'chroma': chroma,
    if (muted) 'muted': true,
  };

  factory fromJson(Map<String, Object?> json) => ChannelMix(
    hue: (json['hue'] as num?)?.toDouble(),
    chroma: (json['chroma'] as num?)?.toDouble(),
    muted: json['muted'] == true,
  );

  @override
  List<Object?> get props => [hue, chroma, muted];
}

/// Everything needed to rebuild a theme, in both brightnesses.
@immutable
class const ThemeRecipe({
  required final Color seed,
  final Variant variant = Variant.tonalSpot,
  final double contrast = 0,

  /// Scales the chroma of primary, secondary, and tertiary. 1 is the style's own.
  final double vivid = 1,

  /// Scales the chroma of the two neutral palettes. 1 is the style's own.
  final double tint = 1,
  final Map<Channel, ChannelMix> mix = const {},
  final String? name,
}) extends Equatable {
  static const vividRange = (0.0, 2.0);
  static const tintRange = (0.0, 4.0);

  ChannelMix mixOf(Channel channel) => mix[channel] ?? ChannelMix.unity;

  /// How much a channel's chroma is scaled, whether the style's or the mix's.
  double scaleOf(Channel channel) => switch (channel) {
    Channel.neutral || Channel.neutralVariant => tint,
    Channel.error => 1,
    _ => vivid,
  };

  /// True when Flutter's `ColorScheme.fromSeed` reproduces this theme.
  bool get isUnmixed => vivid == 1 && tint == 1 && mix.values.every((m) => m.isUnity);

  ThemeRecipe copyWith({
    Color? seed,
    Variant? variant,
    double? contrast,
    double? vivid,
    double? tint,
    Map<Channel, ChannelMix>? mix,
    String? Function()? name,
  }) => ThemeRecipe(
    seed: seed ?? this.seed,
    variant: variant ?? this.variant,
    contrast: contrast ?? this.contrast,
    vivid: vivid ?? this.vivid,
    tint: tint ?? this.tint,
    mix: mix ?? this.mix,
    name: name != null ? name() : this.name,
  );

  ThemeRecipe withMix(Channel channel, ChannelMix value) {
    final next = Map.of(mix);
    if (value.isUnity) {
      next.remove(channel);
    } else {
      next[channel] = value;
    }
    return copyWith(mix: next);
  }

  Map<String, Object?> toJson() => {
    'seed': seed.hex,
    'variant': variant.name,
    'contrast': contrast,
    if (vivid != 1) 'vivid': vivid,
    if (tint != 1) 'tint': tint,
    if (name != null) 'name': name,
    'mix': {for (final e in mix.entries) e.key.key: e.value.toJson()},
  };

  static ThemeRecipe? fromJson(Map<String, Object?> json) {
    final seed = parseColor(json['seed'] as String? ?? '');
    if (seed == null) return null;
    final mixJson = json['mix'] as Map<String, Object?>? ?? const {};
    return ThemeRecipe(
      seed: seed,
      variant: Variant.values.firstWhere((v) => v.name == json['variant'], orElse: () => Variant.tonalSpot),
      contrast: ((json['contrast'] as num?) ?? 0).toDouble().clamp(-1.0, 1.0),
      vivid: ((json['vivid'] as num?) ?? 1).toDouble().clamp(vividRange.$1, vividRange.$2),
      tint: ((json['tint'] as num?) ?? 1).toDouble().clamp(tintRange.$1, tintRange.$2),
      name: json['name'] as String?,
      mix: {
        for (final c in Channel.values)
          if (mixJson[c.key] case final Map<String, Object?> m) c: ChannelMix.fromJson(m),
      },
    );
  }

  @override
  List<Object?> get props => [seed, variant, contrast, vivid, tint, mix, name];
}

/// Material's styles from the calmest to the most colorful.
const styles = [
  Variant.monochrome,
  Variant.neutral,
  Variant.tonalSpot,
  Variant.content,
  Variant.fidelity,
  Variant.vibrant,
  Variant.expressive,
  Variant.rainbow,
  Variant.fruitSalad,
];

extension StyleText on Variant {
  /// What the style feels like, in plain words.
  String get mood => switch (this) {
    Variant.monochrome => 'Gray',
    Variant.neutral => 'Quiet',
    Variant.tonalSpot => 'Balanced',
    Variant.content => 'Natural',
    Variant.fidelity => 'Faithful',
    Variant.vibrant => 'Bold',
    Variant.expressive => 'Expressive',
    Variant.rainbow => 'Playful',
    Variant.fruitSalad => 'Wild',
  };

  /// Material's name for the style.
  String get title => switch (this) {
    Variant.tonalSpot => 'Tonal spot',
    Variant.vibrant => 'Vibrant',
    Variant.expressive => 'Expressive',
    Variant.fidelity => 'Fidelity',
    Variant.content => 'Content',
    Variant.neutral => 'Neutral',
    Variant.monochrome => 'Monochrome',
    Variant.rainbow => 'Rainbow',
    Variant.fruitSalad => 'Fruit salad',
  };

  String get blurb => switch (this) {
    Variant.tonalSpot => 'Soft buttons and a gentle accent. Android’s default.',
    Variant.vibrant => 'Turns up the saturation on buttons in your chosen hue.',
    Variant.expressive => 'Changes the button hue and adds contrasting accents.',
    Variant.fidelity => 'Builds around your color and adds a complementary accent.',
    Variant.content => 'Builds around your color and adds a nearby accent.',
    Variant.neutral => 'Almost gray, with a hint of your color.',
    Variant.monochrome => 'Gray buttons, accents, and backgrounds.',
    Variant.rainbow => 'Colorful buttons and accents on gray backgrounds.',
    Variant.fruitSalad => 'Shifts the button hue and keeps your hue in the accent.',
  };

  String get dartName => 'DynamicSchemeVariant.$name';
}

/// One-tap seeds, 30° apart on the OKLCH wheel at matched lightness and chroma.
const swatches = [
  Color(0xFFF14445),
  Color(0xFFF57404),
  Color(0xFFF4B00C),
  Color(0xFFAFCE0C),
  Color(0xFF28BC5E),
  Color(0xFF08B7A1),
  Color(0xFF05AEDC),
  Color(0xFF2778FA),
  Color(0xFF7048FD),
  Color(0xFFBC40EA),
  Color(0xFFEB37B0),
  Color(0xFFEB3067),
];

/// Hand-picked starting points.
const starters = [
  ThemeRecipe(
    name: 'Classic',
    seed: Color(0xFFF4A78B),
    variant: Variant.tonalSpot,
    mix: {
      Channel.neutral: ChannelMix(hue: 345, chroma: 18),
      Channel.neutralVariant: ChannelMix(hue: 345, chroma: 22),
      Channel.secondary: ChannelMix(hue: 190, chroma: 40),
    },
  ),
  ThemeRecipe(name: 'Ultraviolet', seed: Color(0xFF7048FD), variant: Variant.vibrant),
  ThemeRecipe(name: 'Matcha', seed: Color(0xFF6E8B3D), variant: Variant.content),
  ThemeRecipe(name: 'Tangerine', seed: Color(0xFFFF6A13), variant: Variant.fidelity),
  ThemeRecipe(
    name: 'Fjord',
    seed: Color(0xFF2B7A8C),
    variant: Variant.tonalSpot,
    mix: {Channel.tertiary: ChannelMix(hue: 40, chroma: 34)},
  ),
  ThemeRecipe(name: 'Bubblegum', seed: Color(0xFFFF5FA2), variant: Variant.fruitSalad),
  ThemeRecipe(name: 'Terminal', seed: Color(0xFF19C37D), variant: Variant.vibrant, tint: 0),
  ThemeRecipe(
    name: 'Graphite',
    seed: Color(0xFF4F5B66),
    variant: Variant.monochrome,
    mix: {Channel.tertiary: ChannelMix(hue: 250, chroma: 14)},
  ),
];
