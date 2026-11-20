import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

import '../model/color_math.dart';
import '../model/exporters.dart';
import '../model/recipe.dart';
import '../model/roles.dart';
import '../model/scheme_engine.dart';
import '../state/studio_cubit.dart';
import 'chrome.dart';

/// Every role and palette in the theme, ready to copy.
class const SchemeBoard({super.key}) extends StatefulWidget {
  @override
  State<SchemeBoard> createState() => _SchemeBoardState();
}

class _SchemeBoardState() extends State<SchemeBoard> {
  Brightness? _brightness;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StudioCubit>().state;
    final brightness = _brightness ?? state.brightness;
    final scheme = resolveScheme(state.recipe, brightness);
    final c = scheme.colors;

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: displayStyle(22)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              'Choose a color to copy its hex value.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            SegmentedButton<Brightness>(
              showSelectedIcon: false,
              selected: {brightness},
              segments: const [
                ButtonSegment(value: Brightness.light, label: Text('Light')),
                ButtonSegment(value: Brightness.dark, label: Text('Dark')),
              ],
              onSelectionChanged: (selection) => setState(() => _brightness = selection.single),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: AnimatedTheme(
            data: Theme.of(context).copyWith(colorScheme: c),
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(28)),
              clipBehavior: Clip.antiAlias,
              child: ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  for (final group in RoleGroup.values)
                    section(
                      group.label,
                      _Columns(
                        children: [
                          for (final role in Role.values.where((role) => role.group == group))
                            _RoleTile(role: role, colors: c),
                        ],
                      ),
                    ),
                  section(
                    'Tonal palettes',
                    Column(
                      children: [
                        for (final channel in Channel.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _PaletteRow(channel: channel, palette: scheme.palettes[channel]!),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class const _Columns({required final List<Widget> children}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final minTileWidth = MediaQuery.textScalerOf(context).scale(164);
        final perRow = ((constraints.maxWidth + spacing) / (minTileWidth + spacing)).floor().clamp(1, 4);
        final width = (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

class const _RoleTile({required final Role role, required final ColorScheme colors}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bg = role.of(colors);
    final partner = role.partner;
    final ink = partner != null && contrastRatio(partner.of(colors), bg) >= 3 ? partner.of(colors) : bg.ink;
    final ratio = partner == null ? null : contrastRatio(partner.of(colors), bg);
    return Pressable(
      tooltip: '${role.label} · ${bg.oklchCss}',
      onTap: () => copyText(context, bg.hex, label: '${role.label} ${bg.hex}'),
      pressedScale: 0.97,
      builder: (context, hovered, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 74),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(hovered ? 20 : 16),
          border: Border.all(color: ink.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              role.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: monoStyle(11.5, weight: FontWeight.w700, color: ink),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(bg.hex, style: monoStyle(10.5, color: ink.withValues(alpha: 0.85))),
                Text(
                  ratio != null && hovered ? '${ratio.toStringAsFixed(1)}:1' : 'T${bg.tone}',
                  style: monoStyle(10.5, color: ink.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class const _PaletteRow({required final Channel channel, required final TonalPalette palette}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(channel.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.onSurface)),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 2.0;
            final perRow = ((constraints.maxWidth + gap) / (44 + gap)).floor().clamp(1, paletteTones.length);
            final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final tone in paletteTones)
                  SizedBox(
                    width: width,
                    child: Builder(
                      builder: (context) {
                        final color = Color(palette.get(tone));
                        return Pressable(
                          tooltip: '${channel.label} $tone · ${color.hex}',
                          onTap: () => copyText(context, color.hex, label: '${channel.label} T$tone ${color.hex}'),
                          pressedScale: 1,
                          builder: (context, _, _) => Container(
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                            child: Text('$tone', style: monoStyle(10, color: color.ink)),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
