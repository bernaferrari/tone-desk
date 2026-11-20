import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../model/color_math.dart';
import '../model/image_seeds.dart';
import '../state/studio_cubit.dart';
import 'chrome.dart';

typedef _PhotoChoice = ({Color? seed, bool retry});

/// Lets the user choose a photo, then one of the seeds found in it.
Future<void> pickSeedFromImage(BuildContext context) async {
  final cubit = context.read<StudioCubit>();
  while (context.mounted) {
    final XFile? file;
    try {
      file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Images',
            extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
            mimeTypes: ['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/bmp'],
            uniformTypeIdentifiers: ['public.image'],
          ),
        ],
      );
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the photo picker.')));
      }
      return;
    }
    final selectedFile = file;
    if (selectedFile == null || !context.mounted) return;
    final choice = await showDialog<_PhotoChoice>(
      context: context,
      builder: (_) => _ImageSeedDialog(file: selectedFile),
    );
    if (choice?.retry == true) continue;
    final seed = choice?.seed;
    if (context.mounted && seed != null) cubit.setSeed(seed);
    return;
  }
}

class const _ImageSeedDialog({required final XFile file}) extends StatefulWidget {
  @override
  State<_ImageSeedDialog> createState() => _ImageSeedDialogState();
}

class _ImageSeedDialogState() extends State<_ImageSeedDialog> {
  late final _photo = _readPhoto();

  Future<({Uint8List bytes, List<Color> seeds})> _readPhoto() async {
    final bytes = await widget.file.readAsBytes();
    return (bytes: bytes, seeds: await seedsFromImage(bytes));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: _photo,
      builder: (context, snapshot) {
        final photo = snapshot.data;
        final String? problem = snapshot.hasError
            ? 'Could not read this image. Try a different photo.'
            : photo?.seeds.isEmpty == true
            ? 'No usable colors found in this image.'
            : null;
        return AlertDialog(
          title: Text('Pick a color from a photo', style: displayStyle(24)),
          scrollable: true,
          content: SizedBox(
            width: 380,
            child: switch (problem) {
              final message? => Semantics(liveRegion: true, child: Text(message)),
              _ when photo == null => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(semanticsLabel: 'Finding colors'),
              ),
              _ => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: Image.memory(
                        photo.bytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  Text('Choose a color to use in your theme.', style: TextStyle(color: colors.onSurfaceVariant)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final seed in photo.seeds)
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: seed, foregroundColor: seed.ink),
                          onPressed: () => Navigator.of(context).pop<_PhotoChoice>((seed: seed, retry: false)),
                          child: Text(seed.hex),
                        ),
                    ],
                  ),
                ],
              ),
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            if (problem != null)
              FilledButton(
                onPressed: () => Navigator.of(context).pop<_PhotoChoice>((seed: null, retry: true)),
                child: const Text('Choose another photo'),
              ),
          ],
        );
      },
    );
  }
}
