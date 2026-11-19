import 'dart:math' as math;

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
      pressedScale: 0.9,
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
      pressedScale: 0.9,
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
class const _StylePills() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    final (recipe, brightness) = context.select((StudioCubit c) => (c.state.recipe, c.state.brightness));
    final colors = Theme.of(context).colorScheme;
    final selected = styles.indexOf(recipe.variant);

    void pick(double dx, List<double> widths, double gap) {
      var i = 0;
      for (var x = 0.0; i < widths.length - 1 && dx > x + widths[i] + gap / 2; i++) {
        x += widths[i] + gap;
      }
      if (styles[i] == recipe.variant) return;
      HapticFeedback.selectionClick();
      cubit.setVariant(styles[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 3.0;
            const grow = 1.8;
            final unit = (constraints.maxWidth - gap * (styles.length - 1)) / (styles.length - 1 + grow);
            final widths = [for (var i = 0; i < styles.length; i++) i == selected ? unit * grow : unit];
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => pick(d.localPosition.dx, widths, gap),
                onHorizontalDragUpdate: (d) => pick(d.localPosition.dx, widths, gap),
                child: SizedBox(
                  height: 60,
                  child: Row(
                    spacing: gap,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, v) in styles.indexed)
                        _StyleBand(
                          palettes: resolveScheme(recipe.copyWith(variant: v), brightness).palettes,
                          selected: i == selected,
                          width: widths[i],
                          first: i == 0,
                          last: i == styles.length - 1,
                          tooltip: '${v.mood} · ${v.title}',
                        ),
                    ],
                  ),
                ),
              ),
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
            key: ValueKey(recipe.variant),
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
/// round ends, and the picked one widens into a full pill.
class const _StyleBand({
  required final Map<Channel, TonalPalette> palettes,
  required final bool selected,
  required final double width,
  required final bool first,
  required final bool last,
  required final String tooltip,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 220);
    const morph = Duration(milliseconds: 420);
    final primary = Color(palettes[Channel.primary]!.get(60));
    final round = Radius.circular(math.min(width / 2, 18));
    const tight = Radius.circular(6);
    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: morph,
        curve: Curves.easeOutBack,
        width: width,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.horizontal(
            left: selected || first ? round : tight,
            right: selected || last ? round : tight,
          ),
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
                child: AnimatedScale(
                  duration: morph,
                  curve: Curves.easeOutBack,
                  scale: selected ? 1 : 0.4,
                  child: AnimatedOpacity(
                    duration: duration,
                    opacity: selected ? 1 : 0,
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

/// Exact brand colors and the full mixer, folded away until asked for.
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
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    open ? 'Mixer' : 'More options',
                    key: ValueKey(open),
                    style: open
                        ? displayStyle(19, weight: FontWeight.w600)
                        : TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: hovered ? colors.onSurface : colors.onSurfaceVariant,
                          ),
                  ),
                ),
                if (mixed && !open) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                  ),
                ],
                const Spacer(),
                if (open) ...[
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
                ] else
                  Icon(Icons.expand_more_rounded, size: 20, color: colors.onSurfaceVariant),
              ],
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
