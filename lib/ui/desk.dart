import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

import '../model/recipe.dart';
import '../model/scheme_engine.dart';
import '../state/studio_cubit.dart';
import 'chrome.dart';
import 'controls.dart';

const _stripGap = 2.0;
const _outerRadius = Radius.circular(20);
const _innerRadius = Radius.circular(4);

/// The six tonal palettes as channel strips: standing side by side on a desk,
/// or lying down as rows.
class const Mixer({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rows = context.select((StudioCubit c) => c.state.mixerRows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Turn a knob to shift the hue, slide a fader for more or less color. Tap a knob to type a color.',
          style: TextStyle(fontSize: 12.5, height: 1.4, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
            child: rows ? const _Rows(key: ValueKey('rows')) : const _Desk(key: ValueKey('desk')),
          ),
        ),
      ],
    );
  }
}

class const _Rows({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final last = Channel.values.length - 1;
    return Column(
      spacing: _stripGap,
      children: [
        for (final (i, c) in Channel.values.indexed)
          ChannelStrip(
            channel: c,
            rows: true,
            labelSize: 13,
            radius: BorderRadius.vertical(
              top: i == 0 ? _outerRadius : _innerRadius,
              bottom: i == last ? _outerRadius : _innerRadius,
            ),
          ),
      ],
    );
  }
}

class const _Desk({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final last = Channel.values.length - 1;
        final strip = (constraints.maxWidth - _stripGap * last) / Channel.values.length;
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
          spacing: _stripGap,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, c) in Channel.values.indexed)
              Expanded(
                child: ChannelStrip(
                  channel: c,
                  labelSize: labelSize,
                  radius: BorderRadius.horizontal(
                    left: i == 0 ? _outerRadius : _innerRadius,
                    right: i == last ? _outerRadius : _innerRadius,
                  ),
                ),
              ),
          ],
        );
      },
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
/// tinted with the palette itself, and stands up on the desk or lies down as
/// one of the [rows].
class const ChannelStrip({
  super.key,
  required final Channel channel,
  final bool rows = false,
  final double labelSize = 11.5,
  required final BorderRadius radius,
}) extends StatelessWidget {
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
    final chroma = mix.muted ? 0.0 : palette.chroma.clamp(0.0, channel.maxChroma);
    final ringChroma = channel.maxChroma > 50 ? 48.0 : 24.0;
    final ring = [for (var h = 0; h < 360; h += 15) Color(Hct.from(h.toDouble(), ringChroma, tone).toInt())];
    // Low enough that every strip carries the same weight, whatever its palette.
    final tint = Color(Hct.from(palette.hue, math.min(palette.chroma, 6), state.isDark ? 16 : 94).toInt());
    // The most color this hue can show at the track's tone; past it every
    // band would look the same.
    final reach = Hct.from(hue, 200, tone).chroma.clamp(12.0, channel.maxChroma);

    Future<void> pick() async {
      final picked = await askForPaletteColor(
        context,
        title: 'Your ${channel.label.toLowerCase()} color',
        hue: hue,
        chroma: chroma,
        tone: Hct.fromInt(key.toARGB32()).tone,
      );
      if (picked == null || ((picked.hue - hue).abs() < 0.5 && (picked.chroma - chroma).abs() < 0.5)) return;
      cubit.plugChannel(channel, hue: picked.hue, chroma: picked.chroma);
    }

    final knob = Tooltip(
      message: 'Turn for hue · tap to type a color',
      child: HueKnob(
        size: rows ? 56 : 42,
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
    );
    final fader = AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: mix.muted ? 0.45 : 1,
      child: Fader(
        axis: rows ? Axis.horizontal : Axis.vertical,
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
    );
    final hueReadout = _Readout(text: '${hue.round()}°', changed: mix.hue != null);
    final chromaReadout = _Readout(text: '${chroma.round()}', changed: mix.chroma != null || mix.muted);
    final label = Tooltip(
      message: 'Changes ${_rolesOf(channel)}',
      child: Text(
        channel.label,
        maxLines: 1,
        softWrap: false,
        overflow: rows ? TextOverflow.ellipsis : TextOverflow.visible,
        style: labelStyle(labelSize).copyWith(color: colors.onSurface),
      ),
    );
    final mute = StudioIconButton(
      icon: mix.muted ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      tooltip: mix.muted ? 'Bring the color back' : 'Make ${channel.label.toLowerCase()} gray',
      selected: mix.muted,
      size: 28,
      onTap: () => cubit.toggleMute(channel),
    );

    return _Spotlight(
      active: state.spotlight == channel,
      tick: state.spotlightTick,
      radius: radius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: rows ? const EdgeInsets.fromLTRB(8, 6, 6, 4) : const EdgeInsets.fromLTRB(3, 10, 3, 6),
        decoration: BoxDecoration(color: tint, borderRadius: radius),
        child: rows
            ? Row(
                children: [
                  knob,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // In line with where the fader's track starts.
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(child: label),
                                    const SizedBox(width: 8),
                                    hueReadout,
                                    Text(' · ', style: monoStyle(11, color: colors.onSurfaceVariant)),
                                    chromaReadout,
                                  ],
                                ),
                              ),
                              mute,
                            ],
                          ),
                        ),
                        fader,
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  knob,
                  const SizedBox(height: 5),
                  hueReadout,
                  const SizedBox(height: 8),
                  fader,
                  const SizedBox(height: 6),
                  chromaReadout,
                  const SizedBox(height: 8),
                  label,
                  const SizedBox(height: 4),
                  mute,
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
class const _Spotlight({
  required final bool active,
  required final int tick,
  required final BorderRadius radius,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      key: ValueKey(active ? tick : -1),
      tween: Tween(begin: active ? 1 : 0, end: 0),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOut,
      builder: (context, t, child) => Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          color: colors.primary.withValues(alpha: 0.14 * t),
          border: Border.all(color: colors.primary.withValues(alpha: t), width: 2),
        ),
        child: child,
      ),
      child: child,
    );
  }
}
