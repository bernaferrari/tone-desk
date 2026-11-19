import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

/// Ranks the colors of an image the way Android picks them from a wallpaper.
Future<List<Color>> seedsFromImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: 112);
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (data == null) return const [];

  final pixels = <int>[];
  for (var i = 0; i + 3 < data.lengthInBytes; i += 4) {
    if (data.getUint8(i + 3) < 255) continue;
    pixels.add(0xFF000000 | (data.getUint8(i) << 16) | (data.getUint8(i + 1) << 8) | data.getUint8(i + 2));
  }
  if (pixels.isEmpty) return const [];

  final result = await QuantizerCelebi().quantize(pixels, 128);
  return [for (final argb in Score.score(result.colorToCount, desired: 5)) Color(argb)];
}
