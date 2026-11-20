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

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: colors.surfaceContainerLow,
      constraints: const BoxConstraints(maxWidth: 460),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const FaderMark(size: 44),
                const SizedBox(width: 14),
                Flexible(
                  child: Semantics(
                    header: true,
                    namesRoute: true,
                    child: Text('Tone Desk', style: displayStyle(30, color: colors.onSurface, height: 1.1)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Pick a color, tune your Material 3 palette, and see it on real screens as you work. '
              'Use the mixer to set exact brand colors.',
              style: muted,
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 32,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (color, width) in [
                      (colors.primary, 3),
                      (colors.primaryContainer, 2),
                      (colors.secondaryContainer, 2),
                      (colors.tertiaryContainer, 2),
                      (colors.tertiary, 1),
                    ])
                      Expanded(
                        flex: width,
                        child: ColoredBox(color: color),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
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
            const SizedBox(height: 20),
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 12),
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse('https://github.com/bernaferrari/tone-desk')),
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  iconAlignment: IconAlignment.end,
                  label: const Text('Source on GitHub'),
                ),
                FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to studio')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
