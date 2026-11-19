import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../model/color_math.dart';
import '../model/exporters.dart';
import '../state/studio_cubit.dart';
import 'chrome.dart';

/// The theme as code.
class const ExportBoard({super.key}) extends StatefulWidget {
  @override
  State<ExportBoard> createState() => _ExportBoardState();
}

class _ExportBoardState() extends State<ExportBoard> {
  bool _full = false;

  static String _hint(ExportFormat format, bool unmixed, bool full) => switch (format) {
    ExportFormat.flutter when unmixed && !full =>
      'Paste it in and pass it to MaterialApp. Turn off One-liner to spell out every role.',
    ExportFormat.flutter => 'Every role, for light and dark. Paste it in and pass it to MaterialApp.',
    ExportFormat.css => 'Custom properties with light-dark(), in OKLCH. One block covers both modes.',
    ExportFormat.tailwind => 'Roles as utilities (bg-primary, text-on-surface) and a 50–950 scale per palette.',
    ExportFormat.tokens => 'W3C design tokens for Figma plugins, Style Dictionary, and friends.',
  };

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    final state = context.watch<StudioCubit>().state;
    final colors = Theme.of(context).colorScheme;
    final format = state.exportFormat;
    final unmixed = state.recipe.isUnmixed;
    final code = exportTheme(state.recipe, format, full: _full);
    final lines = code.trimRight().split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Segmented<ExportFormat>(
              value: format,
              values: ExportFormat.values,
              label: (f) => f.label,
              onChanged: cubit.setExportFormat,
            ),
            if (format == ExportFormat.flutter && unmixed)
              PillButton(
                label: _full ? 'Every role' : 'One-liner',
                icon: _full ? Icons.list_rounded : Icons.short_text_rounded,
                tooltip: 'Switch between ColorScheme.fromSeed and every role spelled out',
                onTap: () => setState(() => _full = !_full),
              ),
            PillButton(
              label: 'Copy',
              icon: Icons.content_copy_rounded,
              filled: true,
              onTap: () => copyText(context, code, label: '${format.label} theme'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(_hint(format, unmixed, _full), style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13.5)),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: SelectionArea(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 18),
                itemCount: lines.length,
                itemBuilder: (context, i) => _CodeLine(number: i + 1, text: lines[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final _token = RegExp(
  r'(//.*$|/\*.*?\*/)' // comment
  r'|(Color\(0xFF[0-9A-Fa-f]{6}\)|oklch\([^)]*\)|"#[0-9a-fA-F]{6}")' // color
  r'|("[^"]*"(?=\s*:)|[A-Za-z@$][\w-]*(?=\s*:)|--[\w-]+)' // key or custom property
  r"|('[^']*'|"
  r'"[^"]*")' // string
  r'|(\b\d+(?:\.\d+)?\b)', // number
);

class const _CodeLine({required final int number, required final String text}) extends StatelessWidget {
  static Color? _colorOf(String literal) {
    if (literal.startsWith('Color(0xFF')) return parseColor(literal.substring(10, 16));
    return parseColor(literal.replaceAll('"', ''));
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final base = monoStyle(12.5, color: c.onSurface, weight: FontWeight.w400);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _token.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final s = m[0]!;
      if (m[1] != null) {
        spans.add(
          TextSpan(
            text: s,
            style: TextStyle(color: c.onSurfaceVariant.withValues(alpha: 0.8), fontStyle: FontStyle.italic),
          ),
        );
      } else if (m[2] != null) {
        final color = _colorOf(s);
        if (color != null) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: c.outlineVariant),
                ),
              ),
            ),
          );
        }
        spans.add(
          TextSpan(
            text: s,
            style: TextStyle(color: c.tertiary),
          ),
        );
      } else if (m[3] != null) {
        spans.add(
          TextSpan(
            text: s,
            style: TextStyle(color: c.primary),
          ),
        );
      } else if (m[4] != null) {
        spans.add(
          TextSpan(
            text: s,
            style: TextStyle(color: c.tertiary),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: s,
            style: TextStyle(color: c.secondary),
          ),
        );
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: SelectionContainer.disabled(
              child: Text(
                '$number',
                textAlign: TextAlign.right,
                style: base.copyWith(color: c.onSurfaceVariant.withValues(alpha: 0.45)),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text.rich(TextSpan(style: base, children: spans)),
          ),
        ],
      ),
    );
  }
}
