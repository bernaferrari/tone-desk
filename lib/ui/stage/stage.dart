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
    final state = context.watch<StudioCubit>().state;
    final colors = Theme.of(context).colorScheme;

    final lights = widget.compact ? [state.brightness] : const [Brightness.light, Brightness.dark];

    final phones = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in lights)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _Phone(state: state, brightness: b, screen: _screen, direction: _direction),
            ),
          ),
      ],
    );

    final status = state.inspecting ? 'Hover anything to see its color role' : null;

    final stage = InspectorScope(
      controller: _inspector,
      enabled: state.inspecting,
      onPick: (role) => cubit.spotlight(role.channel),
      child: Listener(
        onPointerHover: (e) => _inspector.move(e.position),
        onPointerMove: (e) => _inspector.move(e.position),
        child: Stack(
          children: [
            Positioned.fill(child: phones),
            if (state.inspecting) Positioned.fill(child: InspectorOverlay(controller: _inspector)),
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
                    scheme: resolveScheme(state.recipe, state.brightness).colors,
                    onChanged: _show,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: StudioIconButton(
                    icon: Icons.ads_click_rounded,
                    tooltip: state.inspecting
                        ? 'Stop inspecting (I)'
                        : 'Inspect: hover the phones to see each color role (I)',
                    selected: state.inspecting,
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
      pressedScale: 0.92,
      builder: (context, hovered, _) => Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(3),
            transform: Matrix4.translationValues(0, selected ? -4 : (hovered ? -2 : 0), 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant.withValues(alpha: 0.6),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: TickerMode(
                enabled: false,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Theme(
                      data: previewTheme(scheme),
                      child: Material(
                        color: scheme.surface,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: phoneSize.width,
                            height: phoneSize.height,
                            child: MediaQuery(
                              data: MediaQuery.of(context).copyWith(padding: const EdgeInsets.only(top: 16)),
                              child: screen.build(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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

class const _Phone({
  required final StudioState state,
  required final Brightness brightness,
  required final MockScreen screen,
  required final int direction,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = resolveScheme(state.recipe, brightness);
    return AnimatedTheme(
      data: previewTheme(scheme.colors),
      duration: const Duration(milliseconds: 180),
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
          child: KeyedSubtree(key: ValueKey(screen), child: screen.build()),
        ),
      ),
    );
  }
}
