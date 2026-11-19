import 'dart:convert';

import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

import 'color_math.dart';
import 'recipe.dart';
import 'roles.dart';
import 'scheme_engine.dart';

enum ExportFormat(final String label, final String language) {
  flutter('Flutter', 'dart'),
  css('CSS', 'css'),
  tailwind('Tailwind v4', 'css'),
  tokens('Design tokens', 'json'),
}

/// Tailwind stop → Material tone.
const tailwindTones = {
  50: 95, 100: 90, 200: 80, 300: 70, 400: 60, 500: 50, //
  600: 40, 700: 30, 800: 20, 900: 10, 950: 5,
};

const paletteTones = [0, 5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 98, 99, 100];

String exportTheme(ThemeRecipe recipe, ExportFormat format, {bool full = false}) {
  final light = resolveScheme(recipe, Brightness.light);
  final dark = resolveScheme(recipe, Brightness.dark);
  return switch (format) {
    ExportFormat.flutter => _flutter(recipe, light, dark, full: full),
    ExportFormat.css => _css(recipe, light, dark),
    ExportFormat.tailwind => _tailwind(recipe, light, dark),
    ExportFormat.tokens => _tokens(recipe, light, dark),
  };
}

String themeTitle(ThemeRecipe recipe) => recipe.name ?? recipe.seed.hex;

String _flutter(ThemeRecipe recipe, StudioScheme light, StudioScheme dark, {required bool full}) {
  final b = StringBuffer('// ${themeTitle(recipe)} · made in Tone Desk\n');
  if (recipe.isUnmixed && !full) {
    b.writeln("// Nothing is mixed, so Flutter can rebuild the whole theme from the seed.");
    for (final (name, brightness) in [('lightTheme', null), ('darkTheme', 'Brightness.dark')]) {
      b
        ..writeln()
        ..writeln('final $name = ThemeData(')
        ..writeln('  colorScheme: ColorScheme.fromSeed(')
        ..writeln('    seedColor: const ${recipe.seed.dartLiteral},');
      if (recipe.variant != Variant.tonalSpot) {
        b.writeln('    dynamicSchemeVariant: ${recipe.variant.dartName},');
      }
      if (recipe.contrast != 0) b.writeln('    contrastLevel: ${recipe.contrast.toStringAsFixed(2)},');
      if (brightness != null) b.writeln('    brightness: $brightness,');
      b
        ..writeln('  ),')
        ..writeln(');');
    }
    return b.toString();
  }

  for (final scheme in [light, dark]) {
    final name = scheme.isDark ? 'darkColorScheme' : 'lightColorScheme';
    b
      ..writeln()
      ..writeln('const $name = ColorScheme(')
      ..writeln('  brightness: Brightness.${scheme.brightness.name},');
    for (final role in Role.values) {
      b.writeln('  ${role.label}: ${role.of(scheme.colors).dartLiteral},');
    }
    b.writeln(');');
  }
  b
    ..writeln()
    ..writeln('final lightTheme = ThemeData(colorScheme: lightColorScheme);')
    ..writeln('final darkTheme = ThemeData(colorScheme: darkColorScheme);');
  return b.toString();
}

String _css(ThemeRecipe recipe, StudioScheme light, StudioScheme dark) {
  final b = StringBuffer()
    ..writeln('/* ${themeTitle(recipe)} · made in Tone Desk */')
    ..writeln('/* Follows `color-scheme`: set it to light or dark on <html> to force a mode. */')
    ..writeln(':root {')
    ..writeln('  color-scheme: light dark;');
  for (final role in Role.values) {
    b.writeln('  --${role.kebab}: light-dark(${role.of(light.colors).oklchCss}, ${role.of(dark.colors).oklchCss});');
  }
  b.writeln('}');
  return b.toString();
}

String _tailwind(ThemeRecipe recipe, StudioScheme light, StudioScheme dark) {
  final b = StringBuffer()
    ..writeln('/* ${themeTitle(recipe)} · made in Tone Desk */')
    ..writeln('@import "tailwindcss";')
    ..writeln()
    ..writeln('@custom-variant dark (&:where(.dark, .dark *));')
    ..writeln();
  for (final (selector, scheme) in [(':root', light), ('.dark', dark)]) {
    b.writeln('$selector {');
    for (final role in Role.values) {
      b.writeln('  --${role.kebab}: ${role.of(scheme.colors).oklchCss};');
    }
    b
      ..writeln('}')
      ..writeln();
  }
  b
    ..writeln('/* bg-primary, text-on-primary, border-outline-variant, … */')
    ..writeln('/* plus a scale per palette: bg-primary-600, bg-neutral-50, … */')
    ..writeln('@theme inline {');
  for (final role in Role.values) {
    b.writeln('  --color-${role.kebab}: var(--${role.kebab});');
  }
  for (final channel in Channel.values) {
    final palette = light.palettes[channel]!;
    final name = _kebab(channel.key);
    b.writeln();
    for (final MapEntry(key: stop, value: tone) in tailwindTones.entries) {
      b.writeln('  --color-$name-$stop: ${Color(palette.get(tone)).oklchCss};');
    }
  }
  b.writeln('}');
  return b.toString();
}

String _tokens(ThemeRecipe recipe, StudioScheme light, StudioScheme dark) {
  Map<String, Object> token(Color color) => {
    r'$type': 'color',
    r'$value': {
      'colorSpace': 'srgb',
      'components': [
        for (final v in [color.r, color.g, color.b]) double.parse(v.toStringAsFixed(4)),
      ],
      'hex': color.hex.toLowerCase(),
    },
  };

  Map<String, Object> palette(TonalPalette p) => {for (final tone in paletteTones) '$tone': token(Color(p.get(tone)))};

  final doc = {
    r'$description': '${themeTitle(recipe)} · made in Tone Desk (W3C design tokens format)',
    r'$extensions': {'studio.color.recipe': recipe.toJson()},
    'light': {for (final role in Role.values) role.label: token(role.of(light.colors))},
    'dark': {for (final role in Role.values) role.label: token(role.of(dark.colors))},
    'palette': {for (final c in Channel.values) c.key: palette(light.palettes[c]!)},
  };
  return const JsonEncoder.withIndent('  ').convert(doc);
}

String _kebab(String camel) => camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '-${m[0]!.toLowerCase()}');
