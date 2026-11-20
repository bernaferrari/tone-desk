import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chrome.dart';

void showAbout(BuildContext context) {
  showDialog<void>(context: context, builder: (context) => const _AboutDialog());
}

class const _AboutDialog() extends StatelessWidget {
  static const _shortcuts = [
    ('Space', 'Shuffle color'),
    ('I', 'Inspect preview'),
    ('D', 'Light / dark'),
    ('C', 'All colors'),
    ('E', 'Export'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.5);

    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: colors.surfaceContainerLow,
      constraints: const BoxConstraints(maxWidth: 460),
      scrollable: true,
      title: Row(
        spacing: 14,
        children: [
          const FaderMark(size: 44),
          Flexible(
            child: Text('Tone Desk', style: displayStyle(30, color: colors.onSurface, height: 1.1)),
          ),
        ],
      ),
      content: SizedBox(
        width: 412,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick a color, tune your Material 3 palette, and see it on real screens as you work. '
              'Use the mixer to set exact brand colors.',
              style: muted,
            ),
            const SizedBox(height: 24),
            Text('Keyboard shortcuts', style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final (key, action) in _shortcuts)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      Container(
                        constraints: const BoxConstraints(minWidth: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          key,
                          textAlign: TextAlign.center,
                          style: monoStyle(12, color: colors.onSurface),
                        ),
                      ),
                      Flexible(child: Text(action, style: muted)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => launchUrl(Uri.parse('https://github.com/bernaferrari/tone-desk')),
          icon: Image.asset(
            'assets/github-mark.png',
            width: 16,
            height: 16,
            color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
            excludeFromSemantics: true,
          ),
          label: const Text('Source'),
        ),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}
