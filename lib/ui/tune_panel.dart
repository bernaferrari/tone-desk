import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

import '../model/color_math.dart';
import '../model/recipe.dart';
import '../model/scheme_engine.dart';
import '../state/studio_cubit.dart';
import 'chrome.dart';
import 'controls.dart';
import 'desk.dart';
import 'seed_panel.dart';

/// Everything that makes the theme, in the order you'd decide it.
class const ThemeControls({super.key, final bool compact = false}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Section(number: 1, title: 'Pick a color', trailing: _SeedChip(), child: _ColorDots()),
          const SizedBox(height: 28),
          const _Section(number: 2, title: 'How colorful?', trailing: _StyleName(), child: _StylePills()),
          const SizedBox(height: 28),
          const _Section(number: 3, title: 'Adjust', child: _Knobs()),
          const SizedBox(height: 16),
          _MoreOptions(compact: compact),
        ],
      ),
    );
  }
}

class const _Section({
  required final int number,
  required final String title,
  required final Widget child,
  final Widget? trailing,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
              child: Text(
                '$number',
                style: monoStyle(11, weight: FontWeight.w700, color: colors.onPrimary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: displayStyle(19, weight: FontWeight.w600)),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

/// The current seed as a swatch and hex. Tap to copy.
class const _SeedChip() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final seed = context.select((StudioCubit c) => c.state.recipe.seed);
    final colors = Theme.of(context).colorScheme;
    return Pressable(
      tooltip: 'Copy',
      onTap: () => copyText(context, seed.hex),
      builder: (context, hovered, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: Color.alphaBlend(colors.onSurface.withValues(alpha: hovered ? 0.06 : 0), colors.surfaceContainerHigh),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: seed, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(seed.hex, style: monoStyle(11.5, color: colors.onSurface)),
          ],
        ),
      ),
    );
  }
}

class const _ColorDots() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    final seed = context.select((StudioCubit c) => c.state.recipe.seed);
    final custom = !swatches.any((s) => s.toARGB32() == seed.toARGB32());
    return LayoutBuilder(
      builder: (context, constraints) {
        const perRow = 7;
        const gap = 8.0;
        final size = math.min((constraints.maxWidth - gap * (perRow - 1)) / perRow, 52.0);
        final items = <Widget>[
          for (final swatch in swatches)
            _Dot(
              color: swatch,
              size: size,
              selected: swatch.toARGB32() == seed.toARGB32(),
              onTap: () => cubit.setSeed(swatch),
            ),
          _ActionDot(
            icon: Icons.edit_outlined,
            tooltip: custom ? 'Your color ${seed.hex}. Tap to change it' : 'Type a color',
            size: size,
            fill: custom ? seed : null,
            onTap: () async {
              final color = await askForColor(context, title: 'Your color', initial: seed);
              if (color != null) cubit.setSeed(color);
            },
          ),
          _ActionDot(
            icon: Icons.image_outlined,
            tooltip: 'Use a photo',
            size: size,
            onTap: () => pickSeedFromImage(context),
          ),
        ];
        return Column(
          spacing: gap,
          children: [
            for (var row = 0; row < items.length; row += perRow)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: items.sublist(row, math.min(row + perRow, items.length)),
              ),
          ],
        );
      },
    );
  }
}

class const _Dot({
  required final Color color,
  required final double size,
  required final bool selected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Pressable(
      tooltip: color.hex,
      onTap: onTap,
      selected: selected,
      pressedScale: 1,
      builder: (context, hovered, _) => _Ring(
        size: size,
        selected: selected,
        hovered: hovered,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: selected ? Icon(Icons.check_rounded, size: size * 0.4, color: color.ink) : null,
        ),
      ),
    );
  }
}

/// A circle that does something instead of picking a preset. Once it holds
/// your own color it fills with it and wears the selection ring.
class const _ActionDot({
  required final IconData icon,
  required final String tooltip,
  required final double size,
  required final VoidCallback onTap,
  final Color? fill,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fill = this.fill;
    return Pressable(
      tooltip: tooltip,
      onTap: onTap,
      pressedScale: 1,
      builder: (context, hovered, _) => _Ring(
        size: size,
        selected: fill != null,
        hovered: hovered,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill ?? (hovered ? colors.surfaceContainerHighest : colors.surfaceContainerHigh),
            border: fill == null ? Border.all(color: colors.outlineVariant, width: 1.5) : null,
          ),
          child: Icon(icon, size: size * 0.4, color: fill?.ink ?? colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

class const _Ring({
  required final double size,
  required final bool selected,
  required final bool hovered,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      padding: EdgeInsets.all(selected ? 4 : (hovered ? 1 : 0)),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? colors.onSurface : Colors.transparent, width: 2),
      ),
      child: child,
    );
  }
}

/// One question instead of nine names: how colorful should it be?
/// The styles as one connected strip. A single spring hands width from the
/// old pick to the new one, so every other band holds still.
class const _StylePills() extends StatefulWidget {
  @override
  State<_StylePills> createState() => _StylePillsState();
}

class _StylePillsState() extends State<_StylePills> with SingleTickerProviderStateMixin {
  /// Material's expressive fast spatial spring, for taps.
  static final _bouncy = SpringDescription.withDampingRatio(mass: 1, stiffness: 800, ratio: 0.6);

  /// Material's standard fast spatial spring: no wobble under a finger.
  static final _steady = SpringDescription.withDampingRatio(mass: 1, stiffness: 1400, ratio: 0.9);

  late final _progress = AnimationController.unbounded(vsync: this, value: 1);
  var _from = <double>[];
  int? _target;
  bool _dragging = false;

  /// Counts picks, so a style revisited mid-fade gets a fresh blurb.
  int _picks = 0;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  /// How far each band has grown, summing to one at every frame.
  List<double> get _weights {
    final t = _progress.value;
    return [for (var i = 0; i < styles.length; i++) lerpDouble(_from[i], i == _target ? 1 : 0, t)!];
  }

  void _retarget(int to) {
    if (to == _target) return;
    _from = _target == null ? [for (var i = 0; i < styles.length; i++) i == to ? 1.0 : 0.0] : _weights;
    _target = to;
    _picks++;
    if (_from[to] == 1) return;
    _progress
      ..value = 0
      ..animateWith(SpringSimulation(_dragging ? _steady : _bouncy, 0, 1, 0));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    final (recipe, brightness) = context.select((StudioCubit c) => (c.state.recipe, c.state.brightness));
    final colors = Theme.of(context).colorScheme;
    _retarget(styles.indexOf(recipe.variant));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 3.0;
            const grow = 1.8;
            final unit = (constraints.maxWidth - gap * (styles.length - 1)) / (styles.length - 1 + grow);
            final palettes = [for (final v in styles) resolveScheme(recipe.copyWith(variant: v), brightness).palettes];
            void select(int i) {
              if (styles[i] == recipe.variant) return;
              HapticFeedback.selectionClick();
              cubit.setVariant(styles[i]);
            }

            return AnimatedBuilder(
              animation: _progress,
              builder: (context, _) {
                final weights = _weights;
                final widths = [for (final w in weights) unit * (1 + (grow - 1) * w)];

                void pick(double dx) {
                  var i = 0;
                  for (var x = 0.0; i < widths.length - 1 && dx > x + widths[i] + gap / 2; i++) {
                    x += widths[i] + gap;
                  }
                  select(i);
                }

                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => pick(d.localPosition.dx),
                    onHorizontalDragStart: (_) => _dragging = true,
                    onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
                    onHorizontalDragEnd: (_) => _dragging = false,
                    onHorizontalDragCancel: () => _dragging = false,
                    child: SizedBox(
                      height: 60,
                      child: Row(
                        spacing: gap,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, v) in styles.indexed)
                            Pressable(
                              tooltip: '${v.mood} · ${v.title}',
                              selected: v == recipe.variant,
                              pressedScale: 1,
                              onTap: () => select(i),
                              builder: (context, _, _) => _StyleBand(
                                palettes: palettes[i],
                                grown: weights[i],
                                width: widths[i],
                                first: i == 0,
                                last: i == styles.length - 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          layoutBuilder: (current, previous) => SizedBox(
            height: 13 * 1.35 * 2,
            child: Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${recipe.variant.mood}. ',
                  style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface),
                ),
                TextSpan(text: recipe.variant.blurb),
              ],
            ),
            key: ValueKey(_picks),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, height: 1.35, color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Material's name for the chosen style, for people who know the spec.
class const _StyleName() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final variant = context.select((StudioCubit c) => c.state.recipe.variant);
    return Text(variant.title, style: monoStyle(11, color: Theme.of(context).colorScheme.onSurfaceVariant));
  }
}

/// One style in the strip: its primary on top, secondary and tertiary below.
/// Shaped like an M3 Expressive connected button group: tight inner corners,
/// round ends, and the picked one widens into a full pill as it [grown]s.
class const _StyleBand({
  required final Map<Channel, TonalPalette> palettes,
  required final double grown,
  required final double width,
  required final bool first,
  required final bool last,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 220);
    final primary = Color(palettes[Channel.primary]!.get(60));
    final g = grown.clamp(0.0, 1.0);
    final round = Radius.circular(math.min(width / 2, 18));
    final inner = Radius.lerp(const Radius.circular(6), round, g)!;
    return Container(
      width: width,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.horizontal(left: first ? round : inner, right: last ? round : inner),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: AnimatedContainer(
              duration: duration,
              color: primary,
              alignment: Alignment.center,
              child: Opacity(
                opacity: g,
                child: Transform.scale(
                  scale: 0.4 + 0.6 * grown,
                  child: Icon(Icons.check_rounded, size: 18, color: primary.ink),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AnimatedContainer(duration: duration, color: Color(palettes[Channel.secondary]!.get(75))),
                ),
                Expanded(
                  child: AnimatedContainer(duration: duration, color: Color(palettes[Channel.tertiary]!.get(70))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class const _Knobs() extends StatelessWidget {
  static String _contrastName(double c) => switch (c) {
    < -0.5 => 'Softer',
    < -0.05 => 'Soft',
    < 0.05 => 'Standard',
    < 0.75 => 'Medium',
    _ => 'High',
  };

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    final recipe = context.select((StudioCubit c) => c.state.recipe);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Expanded(
          child: TickKnob(
            label: 'Vivid',
            value: recipe.vivid / ThemeRecipe.vividRange.$2,
            rest: 1 / ThemeRecipe.vividRange.$2,
            readout: '${(recipe.vivid * 100).round()}%',
            onStart: cubit.beginScrub,
            onEnd: cubit.endScrub,
            onChanged: (v) => cubit.setVivid(v * ThemeRecipe.vividRange.$2, live: true),
          ),
        ),
        Expanded(
          child: TickKnob(
            label: 'Surface tint',
            value: recipe.tint / ThemeRecipe.tintRange.$2,
            rest: 1 / ThemeRecipe.tintRange.$2,
            readout: recipe.tint == 0 ? 'Gray' : '${(recipe.tint * 100).round()}%',
            onStart: cubit.beginScrub,
            onEnd: cubit.endScrub,
            onChanged: (v) => cubit.setTint(v * ThemeRecipe.tintRange.$2, live: true),
          ),
        ),
        Expanded(
          child: TickKnob(
            label: 'Contrast',
            value: (recipe.contrast + 1) / 2,
            rest: 0.5,
            readout: _contrastName(recipe.contrast),
            onStart: cubit.beginScrub,
            onEnd: cubit.endScrub,
            onChanged: (v) => cubit.setContrast(v * 2 - 1, live: true),
          ),
        ),
      ],
    );
  }
}

/// The mixer, folded away under a single row until someone asks for it.
class const _MoreOptions({required final bool compact}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    final state = context.watch<StudioCubit>().state;
    final colors = Theme.of(context).colorScheme;
    final mixed = state.recipe.mix.values.any((m) => !m.isUnity);
    final open = state.mixerOpen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.6)),
        Pressable(
          pressedScale: 1,
          onTap: open ? null : () => cubit.setMixerOpen(true),
          builder: (context, hovered, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              height: 32,
              child: Row(
                children: [
                  Expanded(
                    child: _AxisSwap(
                      open: open,
                      alignment: Alignment.centerLeft,
                      closed: Row(
                        children: [
                          Flexible(
                            child: Text(
                              'More options',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: hovered ? colors.onSurface : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (mixed) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                      opened: Text('Mixer', style: displayStyle(19, weight: FontWeight.w600)),
                    ),
                  ),
                  _AxisSwap(
                    open: open,
                    alignment: Alignment.centerRight,
                    closed: Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: hovered ? colors.onSurface : colors.onSurfaceVariant,
                    ),
                    opened: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: StudioIconButton(
                            icon: state.mixerRows ? Icons.view_column_rounded : Icons.table_rows_rounded,
                            tooltip: state.mixerRows ? 'Stand the channels up' : 'Lay the channels down as rows',
                            size: 32,
                            onTap: () => cubit.setMixerRows(!state.mixerRows),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(animation), child: child),
                          ),
                          child: mixed
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: PillButton(
                                    label: 'Reset',
                                    dense: true,
                                    icon: Icons.restart_alt_rounded,
                                    tooltip: 'Put every palette back the way the style made it',
                                    onTap: cubit.resetMix,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        PillButton(
                          label: 'Done',
                          dense: true,
                          icon: Icons.check_rounded,
                          onTap: () => cubit.setMixerOpen(false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: open
                ? const Padding(key: ValueKey('mixer'), padding: EdgeInsets.only(bottom: 8), child: Mixer())
                : const SizedBox(key: ValueKey('closed'), width: double.infinity),
          ),
        ),
      ],
    );
  }
}

/// A shared-axis swap between the folded and open headers: the open one lives
/// below, so opening lifts the old header out the top while the new one rises
/// in. The old one is gone before the new one shows, so the two never blend.
class const _AxisSwap({
  required final bool open,
  required final Widget closed,
  required final Widget opened,
  required final AlignmentGeometry alignment,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, clipBehavior: Clip.none, children: [...previous, ?current]),
      transitionBuilder: (child, animation) {
        final isOpened = child.key == const ValueKey(true);
        final incoming = child.key == ValueKey(open);
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: incoming ? const Interval(0.35, 1, curve: Curves.easeOut) : const Interval(0.65, 1),
          ),
          child: SlideTransition(
            position: Tween(
              begin: Offset(0, isOpened ? 0.45 : -0.45),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(open), child: open ? opened : closed),
    );
  }
}
