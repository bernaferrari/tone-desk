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
        Row(
          children: [
            Expanded(
              child: Text(
                'Click any color to copy it.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            Segmented<Brightness>(
              value: brightness,
              values: const [Brightness.light, Brightness.dark],
              label: (b) => b == Brightness.light ? 'Light' : 'Dark',
              onChanged: (b) => setState(() => _brightness = b),
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
                  section(
                    'Accents',
                    _Columns(
                      children: [
                        for (final group in const [
                          [Role.primary, Role.primaryContainer],
                          [Role.secondary, Role.secondaryContainer],
                          [Role.tertiary, Role.tertiaryContainer],
                          [Role.error, Role.errorContainer],
                        ])
                          Column(
                            children: [
                              _RoleTile(role: group[0], colors: c, height: 96),
                              const SizedBox(height: 6),
                              _RoleTile(role: group[1], colors: c, height: 72),
                            ],
                          ),
                      ],
                    ),
                  ),
                  section(
                    'Surfaces',
                    Column(
                      children: [
                        _Columns(
                          spacing: 6,
                          children: [
                            for (final r in const [Role.surfaceDim, Role.surface, Role.surfaceBright])
                              _RoleTile(role: r, colors: c, height: 76, outlined: true),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _Columns(
                          spacing: 6,
                          children: [
                            for (final r in const [
                              Role.surfaceContainerLowest,
                              Role.surfaceContainerLow,
                              Role.surfaceContainer,
                              Role.surfaceContainerHigh,
                              Role.surfaceContainerHighest,
                            ])
                              _RoleTile(
                                role: r,
                                colors: c,
                                height: 92,
                                outlined: true,
                                shortLabel: r.label.replaceFirst('surfaceContainer', 'container '),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _Columns(
                          spacing: 6,
                          children: [
                            for (final r in const [
                              Role.onSurface,
                              Role.onSurfaceVariant,
                              Role.outline,
                              Role.outlineVariant,
                            ])
                              _RoleTile(role: r, colors: c, height: 64),
                          ],
                        ),
                      ],
                    ),
                  ),
                  section(
                    'Fixed & inverse',
                    _Columns(
                      spacing: 6,
                      children: [
                        for (final r in const [
                          Role.primaryFixed,
                          Role.secondaryFixed,
                          Role.tertiaryFixed,
                          Role.inverseSurface,
                          Role.inversePrimary,
                        ])
                          _RoleTile(role: r, colors: c, height: 72),
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

class const _Columns({required final List<Widget> children, final double spacing = 10}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Wrap to two per row on narrow screens.
        final perRow = constraints.maxWidth < 520 && children.length > 2 ? 2 : children.length;
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

class const _RoleTile({
  required final Role role,
  required final ColorScheme colors,
  final double height = 80,
  final bool outlined = false,
  final String? shortLabel,
}) extends StatelessWidget {
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
        height: height,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(hovered ? 20 : 16),
          border: outlined ? Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shortLabel ?? role.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: monoStyle(11.5, weight: FontWeight.w700, color: ink),
            ),
            const Spacer(),
            Row(
              children: [
                Text(bg.hex, style: monoStyle(10.5, color: ink.withValues(alpha: 0.85))),
                const Spacer(),
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
    return Row(
      children: [
        SizedBox(
          width: 118,
          child: Text(
            channel.label,
            style: TextStyle(fontWeight: FontWeight.w600, color: colors.onSurface, fontSize: 13),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                for (final tone in paletteTones)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final color = Color(palette.get(tone));
                        return Pressable(
                          tooltip: '${channel.label} $tone · ${color.hex}',
                          onTap: () => copyText(context, color.hex, label: '${channel.label} T$tone ${color.hex}'),
                          pressedScale: 1,
                          builder: (context, hovered, _) => Container(
                            height: 48,
                            color: color,
                            alignment: Alignment.bottomCenter,
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              '$tone',
                              style: monoStyle(
                                hovered ? 11 : 9,
                                weight: hovered ? FontWeight.w800 : FontWeight.w500,
                                color: color.ink.withValues(alpha: hovered ? 1 : 0.7),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
