import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

import '../model/recipe.dart';
import '../model/scheme_engine.dart';
import '../state/studio_cubit.dart';
import 'chrome.dart';
import 'controls.dart';

/// The six tonal palettes as channels on a desk, each with a hue knob on top
/// and a color fader below.
class const Mixer({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Turn a knob to shift the hue, slide a fader for more or less color. Tap a knob to set an exact color.',
          style: TextStyle(fontSize: 12.5, height: 1.4, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 5.0;
            final strip = (constraints.maxWidth - gap * (Channel.values.length - 1)) / Channel.values.length;
            // One size for every name, small enough for the longest to fit.
            final base = DefaultTextStyle.of(context).style.merge(ChannelStrip.labelStyle(11.5));
            var widest = 0.0;
            for (final c in Channel.values) {
              final painter = TextPainter(
                text: TextSpan(text: c.label, style: base),
                textDirection: TextDirection.ltr,
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: 1,
              )..layout();
              widest = math.max(widest, painter.width);
              painter.dispose();
            }
            final labelSize = 11.5 * math.min(1.0, (strip - 8) / widest);
            return Row(
              spacing: gap,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in Channel.values)
                  Expanded(
                    child: ChannelStrip(channel: c, labelSize: labelSize),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

String _rolesOf(Channel channel) => switch (channel) {
  Channel.primary => 'primary, onPrimary, primaryContainer, onPrimaryContainer, inversePrimary, primaryFixed…',
  Channel.secondary => 'secondary, onSecondary, secondaryContainer, onSecondaryContainer, secondaryFixed…',
  Channel.tertiary => 'tertiary, onTertiary, tertiaryContainer, onTertiaryContainer, tertiaryFixed…',
  Channel.neutral => 'surface, surfaceContainer (all five), surfaceDim, surfaceBright, onSurface, inverseSurface',
  Channel.neutralVariant => 'surfaceVariant, onSurfaceVariant, outline, outlineVariant',
  Channel.error => 'error, onError, errorContainer, onErrorContainer',
};

/// One tonal palette as a channel strip: a hue knob wearing its color, a
/// fader for how much color, and a switch that turns it gray. The strip is
/// tinted with the palette itself.
class const ChannelStrip({super.key, required final Channel channel, final double labelSize = 11.5})
    extends StatelessWidget {
  static TextStyle labelStyle(double size) => TextStyle(fontSize: size, fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    final state = context.watch<StudioCubit>().state;
    final colors = Theme.of(context).colorScheme;
    final scheme = resolveScheme(state.recipe, state.brightness);
    final palette = scheme.palettes[channel]!;
    final style = scheme.stylePalettes[channel]!;
    final mix = state.recipe.mixOf(channel);
    final key = scheme.keyOf(channel);
    final tone = state.isDark ? 70.0 : 55.0;

    final hue = mix.hue ?? style.hue;
    final chroma = mix.muted ? 0.0 : (mix.chroma ?? style.chroma).clamp(0.0, channel.maxChroma);
    final ringChroma = channel.maxChroma > 50 ? 48.0 : 24.0;
    final ring = [for (var h = 0; h < 360; h += 15) Color(Hct.from(h.toDouble(), ringChroma, tone).toInt())];
    final tint = Color(Hct.from(palette.hue, math.min(palette.chroma, 16), state.isDark ? 16 : 94).toInt());
    // The most color this hue can show at the track's tone; past it every
    // band would look the same.
    final reach = Hct.from(hue, 200, tone).chroma.clamp(12.0, channel.maxChroma);

    Future<void> pick() async {
      final color = await askForColor(
        context,
        title: 'Your ${channel.label.toLowerCase()} color',
        initial: key,
        action: 'Use it',
      );
      if (color != null) cubit.plugChannel(channel, color);
    }

    return _Spotlight(
      active: state.spotlight == channel,
      tick: state.spotlightTick,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(3, 10, 3, 6),
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Tooltip(
              message: 'Turn for hue · tap to set an exact color',
              child: HueKnob(
                size: 42,
                label: '${channel.label} hue',
                hue: hue,
                unity: style.hue,
                ring: ring,
                center: key,
                rim: tint,
                onTap: pick,
                onStart: cubit.beginScrub,
                onEnd: cubit.endScrub,
                onReset: () => cubit.setChannelHue(channel, null),
                onChanged: (h) => cubit.setChannelHue(channel, h, live: true),
              ),
            ),
            const SizedBox(height: 5),
            _Readout(text: '${hue.round()}°', changed: mix.hue != null),
            const SizedBox(height: 8),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: mix.muted ? 0.45 : 1,
              child: Fader(
                value: (chroma / reach).clamp(0.0, 1.0),
                unity: (style.chroma / reach).clamp(0.0, 1.0),
                colorAt: (t) => Color(Hct.from(hue, t * reach, tone).toInt()),
                rim: tint,
                semanticLabel: '${channel.label} chroma',
                semanticValue: chroma.round().toString(),
                onStart: cubit.beginScrub,
                onEnd: cubit.endScrub,
                onReset: () => cubit.setChannelChroma(channel, null),
                onChanged: (v) => cubit.setChannelChroma(channel, v * reach, live: true),
              ),
            ),
            const SizedBox(height: 6),
            _Readout(text: '${chroma.round()}', changed: mix.chroma != null || mix.muted),
            const SizedBox(height: 8),
            Tooltip(
              message: 'Changes ${_rolesOf(channel)}',
              child: Text(
                channel.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: labelStyle(labelSize).copyWith(color: colors.onSurface),
              ),
            ),
            const SizedBox(height: 4),
            StudioIconButton(
              icon: mix.muted ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              tooltip: mix.muted ? 'Bring the color back' : 'Make ${channel.label.toLowerCase()} gray',
              selected: mix.muted,
              size: 28,
              onTap: () => cubit.toggleMute(channel),
            ),
          ],
        ),
      ),
    );
  }
}

class const _Readout({required final String text, required final bool changed}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Text(
      text,
      style: monoStyle(
        11,
        color: changed ? colors.primary : colors.onSurfaceVariant,
        weight: changed ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

/// Briefly rings a strip when the inspector points at its channel.
class const _Spotlight({required final bool active, required final int tick, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      key: ValueKey(active ? tick : -1),
      tween: Tween(begin: active ? 1 : 0, end: 0),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOut,
      builder: (context, t, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: colors.primary.withValues(alpha: 0.14 * t),
          border: Border.all(color: colors.primary.withValues(alpha: t), width: 2),
        ),
        child: child,
      ),
      child: child,
    );
  }
}
