import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

import 'recipe.dart';

/// A recipe resolved for one brightness.
class StudioScheme({
  required final ThemeRecipe recipe,
  required final Brightness brightness,
  required final DynamicScheme scheme,
  required final ColorScheme colors,

  /// The palettes after mixing.
  required final Map<Channel, TonalPalette> palettes,

  /// The palettes the style generates on its own: the desk's unity marks.
  required final Map<Channel, TonalPalette> stylePalettes,
}) {
  bool get isDark => brightness == Brightness.dark;

  /// The color that best represents a channel on this brightness.
  Color keyOf(Channel channel) => switch (channel) {
    Channel.primary => colors.primary,
    Channel.secondary => colors.secondary,
    Channel.tertiary => colors.tertiary,
    Channel.error => colors.error,
    Channel.neutral => Color(palettes[channel]!.get(isDark ? 70 : 40)),
    Channel.neutralVariant => Color(palettes[channel]!.get(isDark ? 70 : 40)),
  };
}

DynamicScheme styleScheme(Variant variant, Hct source, bool isDark, double contrast) => switch (variant) {
  Variant.monochrome => SchemeMonochrome(sourceColorHct: source, isDark: isDark, contrastLevel: contrast),
  Variant.neutral => SchemeNeutral(sourceColorHct: source, isDark: isDark, contrastLevel: contrast),
  Variant.tonalSpot => SchemeTonalSpot(sourceColorHct: source, isDark: isDark, contrastLevel: contrast),
  Variant.vibrant => SchemeVibrant(sourceColorHct: source, isDark: isDark, contrastLevel: contrast),
  Variant.expressive => SchemeExpressive(sourceColorHct: source, isDark: isDark, contrastLevel: contrast),
  Variant.content => SchemeContent(sourceColorHct: source, isDark: isDark, contrastLevel: contrast),
  Variant.fidelity => SchemeFidelity(sourceColorHct: source, isDark: isDark, contrastLevel: contrast),
  Variant.rainbow => SchemeRainbow(sourceColorHct: source, isDark: isDark, contrastLevel: contrast),
  Variant.fruitSalad => SchemeFruitSalad(sourceColorHct: source, isDark: isDark, contrastLevel: contrast),
};

Map<Channel, TonalPalette> palettesOf(DynamicScheme s) => {
  Channel.primary: s.primaryPalette,
  Channel.secondary: s.secondaryPalette,
  Channel.tertiary: s.tertiaryPalette,
  Channel.neutral: s.neutralPalette,
  Channel.neutralVariant: s.neutralVariantPalette,
  Channel.error: s.errorPalette,
};

final _cache = <(ThemeRecipe, Brightness), StudioScheme>{};

/// Resolves [recipe] for [brightness].
StudioScheme resolveScheme(ThemeRecipe recipe, Brightness brightness) {
  final key = (recipe, brightness);
  if (_cache.remove(key) case final hit?) return _cache[key] = hit;

  final isDark = brightness == Brightness.dark;
  final source = Hct.fromInt(recipe.seed.toARGB32());
  final base = styleScheme(recipe.variant, source, isDark, recipe.contrast);
  final stylePalettes = {
    for (final MapEntry(key: channel, value: p) in palettesOf(base).entries)
      channel: _scaled(p, recipe.scaleOf(channel)),
  };

  final palettes = <Channel, TonalPalette>{};
  for (final channel in Channel.values) {
    final style = stylePalettes[channel]!;
    final mix = recipe.mixOf(channel);
    final chroma = switch (mix) {
      ChannelMix(muted: true) => 0.0,
      ChannelMix(chroma: final c?) => c * recipe.scaleOf(channel),
      _ => style.chroma,
    };
    palettes[channel] = mix.isUnity ? style : TonalPalette.of(mix.hue ?? style.hue, chroma);
  }

  final scheme = DynamicScheme(
    sourceColorHct: source,
    variant: recipe.variant,
    contrastLevel: recipe.contrast,
    isDark: isDark,
    primaryPalette: palettes[Channel.primary]!,
    secondaryPalette: palettes[Channel.secondary]!,
    tertiaryPalette: palettes[Channel.tertiary]!,
    neutralPalette: palettes[Channel.neutral]!,
    neutralVariantPalette: palettes[Channel.neutralVariant]!,
    errorPalette: palettes[Channel.error]!,
  );

  final result = StudioScheme(
    recipe: recipe,
    brightness: brightness,
    scheme: scheme,
    colors: colorSchemeOf(scheme, brightness),
    palettes: palettes,
    stylePalettes: stylePalettes,
  );
  _cache[key] = result;
  if (_cache.length > 96) _cache.remove(_cache.keys.first);
  return result;
}

/// Scales a palette's chroma from what it actually reaches, since styles
/// like vibrant ask for far more chroma than any screen can show.
TonalPalette _scaled(TonalPalette p, double scale) {
  if (scale == 1) return p;
  final reached = p.chroma < p.keyColor.chroma ? p.chroma : p.keyColor.chroma;
  // Even a gray palette can be tinted, so give it something to scale.
  return TonalPalette.of(p.hue, (reached < 2 ? 8.0 * (scale - 1).clamp(0, 4) : reached * scale));
}

ColorScheme colorSchemeOf(DynamicScheme s, Brightness brightness) {
  Color c(int argb) => Color(argb);
  return ColorScheme(
    brightness: brightness,
    primary: c(s.primary),
    onPrimary: c(s.onPrimary),
    primaryContainer: c(s.primaryContainer),
    onPrimaryContainer: c(s.onPrimaryContainer),
    primaryFixed: c(s.primaryFixed),
    primaryFixedDim: c(s.primaryFixedDim),
    onPrimaryFixed: c(s.onPrimaryFixed),
    onPrimaryFixedVariant: c(s.onPrimaryFixedVariant),
    secondary: c(s.secondary),
    onSecondary: c(s.onSecondary),
    secondaryContainer: c(s.secondaryContainer),
    onSecondaryContainer: c(s.onSecondaryContainer),
    secondaryFixed: c(s.secondaryFixed),
    secondaryFixedDim: c(s.secondaryFixedDim),
    onSecondaryFixed: c(s.onSecondaryFixed),
    onSecondaryFixedVariant: c(s.onSecondaryFixedVariant),
    tertiary: c(s.tertiary),
    onTertiary: c(s.onTertiary),
    tertiaryContainer: c(s.tertiaryContainer),
    onTertiaryContainer: c(s.onTertiaryContainer),
    tertiaryFixed: c(s.tertiaryFixed),
    tertiaryFixedDim: c(s.tertiaryFixedDim),
    onTertiaryFixed: c(s.onTertiaryFixed),
    onTertiaryFixedVariant: c(s.onTertiaryFixedVariant),
    error: c(s.error),
    onError: c(s.onError),
    errorContainer: c(s.errorContainer),
    onErrorContainer: c(s.onErrorContainer),
    surface: c(s.surface),
    onSurface: c(s.onSurface),
    surfaceDim: c(s.surfaceDim),
    surfaceBright: c(s.surfaceBright),
    surfaceContainerLowest: c(s.surfaceContainerLowest),
    surfaceContainerLow: c(s.surfaceContainerLow),
    surfaceContainer: c(s.surfaceContainer),
    surfaceContainerHigh: c(s.surfaceContainerHigh),
    surfaceContainerHighest: c(s.surfaceContainerHighest),
    onSurfaceVariant: c(s.onSurfaceVariant),
    outline: c(s.outline),
    outlineVariant: c(s.outlineVariant),
    shadow: c(s.shadow),
    scrim: c(s.scrim),
    inverseSurface: c(s.inverseSurface),
    onInverseSurface: c(s.inverseOnSurface),
    inversePrimary: c(s.inversePrimary),
    surfaceTint: c(s.surfaceTint),
  );
}
