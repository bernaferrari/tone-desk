import 'package:tone_desk/model/color_math.dart';
import 'package:tone_desk/model/exporters.dart';
import 'package:tone_desk/model/recipe.dart';
import 'package:tone_desk/model/scheme_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

bool isGray(Color c) {
  final argb = c.toARGB32();
  final (r, g, b) = ((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);
  return (r - g).abs() <= 1 && (g - b).abs() <= 1;
}

void main() {
  group('parseColor', () {
    test('reads hex, rgb, hsl and oklch', () {
      expect(parseColor('#6B3BFF')?.hex, '#6B3BFF');
      expect(parseColor('6b3bff')?.hex, '#6B3BFF');
      expect(parseColor('rgb(255, 0, 0)')?.hex, '#FF0000');
      expect(parseColor('hsl(120, 100%, 50%)')?.hex, '#00FF00');
      expect(parseColor('oklch(62.8% 0.2577 29.23)')?.hex, '#FF0000');
    });

    test('rejects nonsense', () {
      expect(parseColor(''), isNull);
      expect(parseColor('banana'), isNull);
    });
  });

  group('resolveScheme', () {
    const recipe = ThemeRecipe(seed: Color(0xFF6B3BFF), variant: Variant.tonalSpot);

    test('vivid scales accent chroma, tint scales neutrals', () {
      final base = resolveScheme(recipe, Brightness.light);
      final vivid = resolveScheme(recipe.copyWith(vivid: 2), Brightness.light);
      final gray = resolveScheme(recipe.copyWith(tint: 0), Brightness.light);
      expect(vivid.stylePalettes[Channel.primary]!.chroma, greaterThan(base.stylePalettes[Channel.primary]!.chroma));
      expect(gray.stylePalettes[Channel.neutral]!.chroma, 0);
      expect(isGray(gray.colors.surface), isTrue);
    });

    test('muting a channel drains it to gray', () {
      final muted = resolveScheme(recipe.withMix(Channel.primary, const ChannelMix(muted: true)), Brightness.light);
      expect(isGray(muted.colors.primary), isTrue);
      expect(muted.colors.tertiary.hct.chroma, greaterThan(10));
    });
  });

  group('exportTheme', () {
    test('an untouched recipe exports as a fromSeed one-liner', () {
      const recipe = ThemeRecipe(seed: Color(0xFF6B3BFF), variant: Variant.vibrant);
      final code = exportTheme(recipe, ExportFormat.flutter);
      expect(code, contains('ColorScheme.fromSeed'));
      expect(code, contains('DynamicSchemeVariant.vibrant'));
    });

    test('a mixed recipe exports every role', () {
      final recipe = const ThemeRecipe(seed: Color(0xFF6B3BFF)).copyWith(vivid: 1.5);
      expect(exportTheme(recipe, ExportFormat.flutter), isNot(contains('fromSeed')));
    });

    test('css and tailwind speak oklch', () {
      const recipe = ThemeRecipe(seed: Color(0xFF6B3BFF));
      expect(exportTheme(recipe, ExportFormat.css), contains('light-dark(oklch('));
      expect(exportTheme(recipe, ExportFormat.tailwind), contains('@theme inline'));
    });
  });

  test('recipes survive a JSON round trip', () {
    for (final recipe in starters) {
      expect(ThemeRecipe.fromJson(recipe.toJson()), recipe.copyWith());
    }
  });
}
