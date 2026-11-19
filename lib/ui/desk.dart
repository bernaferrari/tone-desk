import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

import '../model/recipe.dart';
import '../model/scheme_engine.dart';
import '../state/studio_cubit.dart';
import 'chrome.dart';
import 'controls.dart';

/// The six tonal palettes, one row each, with a hue knob and a color slider.
class const Mixer({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Turn a knob to shift the hue, slide for more or less color. Tap a color to set it exactly.',
          style: TextStyle(fontSize: 12.5, height: 1.4, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        for (final (i, c) in Channel.values.indexed) ...[
          if (i > 0) const SizedBox(height: 6),
          ChannelStrip(channel: c),
        ],
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

/// One tonal palette: a hue knob holding its color, a chroma slider, and a
/// switch that turns it gray. The row is tinted with the palette itself.
class const ChannelStrip({super.key, required final Channel channel}) extends StatelessWidget {
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
    final ringChroma = channel.maxChroma > 50 ? 60.0 : 24.0;
    final ring = [for (var h = 0; h < 360; h += 30) Color(Hct.from(h.toDouble(), ringChroma, tone).toInt())];
    final tint = Color(palette.get(state.isDark ? 17 : 95));
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
        padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
        decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Tooltip(
              message: 'Turn for hue · tap to set an exact color',
              child: HueKnob(
                size: 54,
                hue: hue,
                unity: style.hue,
                ring: ring,
                center: key,
                onTap: pick,
                onStart: cubit.beginScrub,
                onEnd: cubit.endScrub,
                onReset: () => cubit.setChannelHue(channel, null),
                onChanged: (h) => cubit.setChannelHue(channel, h, live: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Tooltip(
                                message: 'Changes ${_rolesOf(channel)}',
                                child: Text(
                                  channel.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _Readout(text: '${hue.round()}°', changed: mix.hue != null),
                            Text(' · ', style: monoStyle(11, color: colors.onSurfaceVariant)),
                            _Readout(text: '${chroma.round()}', changed: mix.chroma != null || mix.muted),
                          ],
                        ),
                      ),
                      StudioIconButton(
                        icon: mix.muted ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        tooltip: mix.muted ? 'Bring the color back' : 'Make ${channel.label.toLowerCase()} gray',
                        selected: mix.muted,
                        size: 26,
                        onTap: () => cubit.toggleMute(channel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: mix.muted ? 0.45 : 1,
                    child: BandSlider(
                      height: 22,
                      value: (chroma / reach).clamp(0.0, 1.0),
                      unity: (style.chroma / reach).clamp(0.0, 1.0),
                      colorAt: (t) => Color(Hct.from(hue, t * reach, tone).toInt()),
                      semanticLabel: '${channel.label} chroma',
                      semanticValue: chroma.round().toString(),
                      onStart: cubit.beginScrub,
                      onEnd: cubit.endScrub,
                      onReset: () => cubit.setChannelChroma(channel, null),
                      onChanged: (v) => cubit.setChannelChroma(channel, v * reach, live: true),
                    ),
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
          borderRadius: BorderRadius.circular(18),
          color: colors.primary.withValues(alpha: 0.14 * t),
          border: Border.all(color: colors.primary.withValues(alpha: t), width: 2),
        ),
        child: child,
      ),
      child: child,
    );
  }
}
