import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../model/color_math.dart';
import '../model/image_seeds.dart';
import '../state/studio_cubit.dart';
import 'chrome.dart';

/// Lets the user choose a photo, then one of the seeds found in it.
Future<void> pickSeedFromImage(BuildContext context) async {
  final cubit = context.read<StudioCubit>();
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Images',
        extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
        mimeTypes: ['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/bmp'],
        uniformTypeIdentifiers: ['public.image'],
      ),
    ],
  );
  if (file == null || !context.mounted) return;
  final bytes = await file.readAsBytes();
  if (!context.mounted) return;
  final picked = await showDialog<Color>(
    context: context,
    builder: (_) => _ImageSeedDialog(bytes: bytes),
  );
  if (picked != null) cubit.setSeed(picked);
}

class const _ImageSeedDialog({required final Uint8List bytes}) extends StatefulWidget {
  @override
  State<_ImageSeedDialog> createState() => _ImageSeedDialogState();
}

class _ImageSeedDialogState() extends State<_ImageSeedDialog> {
  late final Future<List<Color>> _seeds = seedsFromImage(widget.bytes);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('Pick a seed', style: displayStyle(24)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: Image.memory(widget.bytes, fit: BoxFit.cover, width: double.infinity),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'The colors Android would choose from this as a wallpaper.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FutureBuilder(
              future: _seeds,
              builder: (context, snapshot) {
                final seeds = snapshot.data;
                if (seeds == null) {
                  return const SizedBox(height: 56, child: Center(child: LinearProgressIndicator()));
                }
                if (seeds.isEmpty) return const Text('No usable colors found in this image.');
                return Row(
                  children: [
                    for (final seed in seeds)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Pressable(
                            tooltip: seed.hex,
                            onTap: () => Navigator.of(context).pop(seed),
                            builder: (context, hovered, _) => AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              height: 56,
                              decoration: BoxDecoration(
                                color: seed,
                                borderRadius: BorderRadius.circular(hovered ? 20 : 16),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
    );
  }
}

/// Drag across hue and tone; the whole studio follows your finger.
