import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../model/scheme_engine.dart';
import '../../state/studio_cubit.dart';
import '../chrome.dart';
import 'phone.dart';
import 'probe.dart';
import 'screens.dart';

/// Mock apps wearing the theme, in light and dark.
class const Stage({super.key, final bool compact = false}) extends StatefulWidget {
  @override
  State<Stage> createState() => _StageState();
}

class _StageState() extends State<Stage> {
  final _inspector = InspectorController();
  MockScreen _screen = MockScreen.wrapped;
  int _direction = 1;
  ColorScheme? _thumbScheme;

  void _show(MockScreen next) {
    if (next == _screen) return;
    setState(() {
      _direction = next.index > _screen.index ? 1 : -1;
      _screen = next;
    });
  }

  void _go(int step) {
    const all = MockScreen.values;
    setState(() {
      _direction = step;
      _screen = all[(_screen.index + step) % all.length];
    });
  }

  @override
  void dispose() {
    _inspector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    final (brightness, inspecting, settledRecipe) = context.select(
      (StudioCubit c) => (c.state.brightness, c.state.inspecting, c.state.scrubbing ? null : c.state.recipe),
    );
    final colors = Theme.of(context).colorScheme;
    if (settledRecipe != null || _thumbScheme == null) {
      _thumbScheme = resolveScheme(settledRecipe ?? cubit.state.recipe, brightness).colors;
    }

    final lights = widget.compact ? [brightness] : const [Brightness.light, Brightness.dark];

    final phones = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in lights)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: RepaintBoundary(
                child: _Phone(brightness: b, screen: _screen, direction: _direction),
              ),
            ),
          ),
      ],
    );

    final status = inspecting ? 'Hover anything to see its color role' : null;

    final stage = InspectorScope(
      controller: _inspector,
      enabled: inspecting,
      onPick: (role) => cubit.spotlight(role.channel),
      child: Listener(
        onPointerHover: (e) => _inspector.move(e.position),
        onPointerMove: (e) => _inspector.move(e.position),
        child: Stack(
          children: [
            Positioned.fill(child: phones),
            if (inspecting) Positioned.fill(child: InspectorOverlay(controller: _inspector)),
            if (status != null)
              Positioned(
                top: 22,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: colors.inverseSurface, borderRadius: BorderRadius.circular(99)),
                    child: Text(status, style: TextStyle(fontSize: 12.5, color: colors.onInverseSurface)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return BlocListener<StudioCubit, StudioState>(
      listenWhen: (a, b) => a.inspecting != b.inspecting,
      listener: (_, _) => _inspector.clear(),
      child: GestureDetector(
        onHorizontalDragEnd: (d) => switch (d.primaryVelocity ?? 0) {
          < -250 => _go(1),
          > 250 => _go(-1),
          _ => null,
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.compact) SizedBox(height: 560, child: stage) else Expanded(child: stage),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!widget.compact) const SizedBox(width: 40),
                Expanded(
                  child: _ScreenStrip(
                    screen: _screen,
                    scheme: _thumbScheme!,
                    onChanged: _show,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: StudioIconButton(
                    icon: Icons.ads_click_rounded,
                    tooltip: inspecting
                        ? 'Stop inspecting (I)'
                        : 'Inspect: hover the phones to see each color role (I)',
                    selected: inspecting,
                    onTap: cubit.toggleInspecting,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Square previews of every sample screen. Tap one, or swipe the stage.
class const _ScreenStrip({
  required final MockScreen screen,
  required final ColorScheme scheme,
  required final ValueChanged<MockScreen> onChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: Center(
        child: ListView(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
          children: [
            for (final s in MockScreen.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _Thumb(screen: s, scheme: scheme, selected: s == screen, onTap: () => onChanged(s)),
              ),
          ],
        ),
      ),
    );
  }
}

class const _Thumb({
  required final MockScreen screen,
  required final ColorScheme scheme,
  required final bool selected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Pressable(
      tooltip: screen.label,
      onTap: onTap,
      selected: selected,
      pressedScale: 0.92,
      builder: (context, hovered, _) => Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 72,
            height: 72,
            transform: Matrix4.translationValues(0, selected ? -4 : (hovered ? -2 : 0), 0),
            child: selected
                ? LiveColors(
                    builder: (context, liveColors, child) => DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: liveColors.primary, width: 2),
                      ),
                      child: child,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: _ThumbScreen(screen: screen, scheme: scheme),
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6), width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: _ThumbScreen(screen: screen, scheme: scheme),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            screen.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? colors.onSurface : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cached thumbnail preview so scrubbing the seed doesn't rebuild all five
/// miniature mock screens on every frame.
class const _ThumbScreen({required final MockScreen screen, required final ColorScheme scheme}) extends StatefulWidget {
  @override
  State<_ThumbScreen> createState() => _ThumbScreenState();
}

class _ThumbScreenState() extends State<_ThumbScreen> {
  Widget? _cached;

  @override
  void didUpdateWidget(_ThumbScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screen != widget.screen || oldWidget.scheme != widget.scheme) {
      _cached = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _cached ??= RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: TickerMode(
          enabled: false,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Theme(
                data: previewTheme(widget.scheme),
                child: Material(
                  color: widget.scheme.surface,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: phoneSize.width,
                      height: phoneSize.height,
                      child: MediaQuery(
                        data: const MediaQueryData(size: phoneSize, padding: EdgeInsets.only(top: 16)),
                        child: widget.screen.build(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class const _Phone({
  required final Brightness brightness,
  required final MockScreen screen,
  required final int direction,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final (recipe, scrubbing) = context.select((StudioCubit c) => (c.state.recipe, c.state.scrubbing));
    final scheme = resolveScheme(recipe, brightness);
    return AnimatedTheme(
      data: previewTheme(scheme.colors),
      duration: scrubbing ? Duration.zero : const Duration(milliseconds: 180),
      child: PhoneFrame(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey(screen);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: Offset((incoming ? 0.16 : -0.16) * direction, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: ExcludeFocus(key: ValueKey(screen), child: screen.build()),
        ),
      ),
    );
  }
}
