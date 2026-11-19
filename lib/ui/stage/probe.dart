import 'package:material_ui/material_ui.dart';

import '../../model/color_math.dart';
import '../../model/roles.dart';
import '../chrome.dart';

class ProbeHit(final Role role, final Color color, final Rect globalRect, final Brightness brightness);

/// Tracks which probe the pointer is over. The innermost one wins.
class InspectorController() extends ChangeNotifier {
  final _stack = <(Object, ProbeHit? Function())>[];
  Offset? pointer;

  /// Measured when asked, so the outline follows its probe through scrolls.
  ProbeHit? get hit => _stack.isEmpty ? null : _stack.last.$2();

  void enter(Object token, ProbeHit? Function() locate) {
    _stack
      ..removeWhere((e) => e.$1 == token)
      ..add((token, locate));
    notifyListeners();
  }

  void exit(Object token) {
    final before = _stack.length;
    _stack.removeWhere((e) => e.$1 == token);
    if (_stack.length != before) notifyListeners();
  }

  /// For widgets going away mid-frame, when listeners must not rebuild.
  void forget(Object token) => _stack.removeWhere((e) => e.$1 == token);

  void move(Offset global) {
    pointer = global;
    if (_stack.isNotEmpty) notifyListeners();
  }

  void clear() {
    _stack.clear();
    pointer = null;
    notifyListeners();
  }

  Object? _lastDown;

  /// The first probe to see a pointer-down is the deepest one under it.
  bool claim(PointerDownEvent event) {
    final id = (event.pointer, event.timeStamp);
    if (_lastDown == id) return false;
    _lastDown = id;
    return true;
  }
}

class const InspectorScope({
  super.key,
  required final InspectorController controller,
  required final bool enabled,
  required final ValueChanged<Role> onPick,
  required super.child,
}) extends InheritedWidget {
  static InspectorScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<InspectorScope>();

  @override
  bool updateShouldNotify(InspectorScope old) => old.enabled != enabled || old.controller != controller;
}

/// Marks a piece of a mock screen with the color role it shows.
class const Probe({super.key, required final Role role, required final Widget child}) extends StatefulWidget {
  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState() extends State<Probe> {
  InspectorController? _controller;

  ProbeHit? _hit() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final rect = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
    final colors = Theme.of(context).colorScheme;
    return ProbeHit(widget.role, widget.role.of(colors), rect, colors.brightness);
  }

  @override
  void dispose() {
    _controller?.forget(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = InspectorScope.of(context);
    if (scope == null || !scope.enabled) {
      _controller?.forget(this);
      _controller = null;
      return widget.child;
    }
    _controller = scope.controller;
    return Listener(
      onPointerDown: (event) {
        if (scope.controller.claim(event)) scope.onPick(widget.role);
      },
      child: MouseRegion(
        onEnter: (_) => scope.controller.enter(this, () => mounted ? _hit() : null),
        onExit: (_) => scope.controller.exit(this),
        child: widget.child,
      ),
    );
  }
}

/// Draws the outline and label for whatever probe is under the pointer.
class const InspectorOverlay({super.key, required final InspectorController controller}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final hit = controller.hit;
          final box = context.findRenderObject() as RenderBox?;
          if (hit == null || box == null || !box.hasSize) return const SizedBox.expand();
          final origin = box.localToGlobal(Offset.zero);
          final rect = hit.globalRect.shift(-origin);
          final pointer = (controller.pointer ?? hit.globalRect.center) - origin;
          final partner = hit.role.partner;

          const labelW = 236.0;
          var lx = pointer.dx + 16;
          var ly = pointer.dy + 18;
          if (lx + labelW > box.size.width) lx = pointer.dx - labelW - 12;
          if (ly + 74 > box.size.height) ly = pointer.dy - 86;

          return Stack(
            children: [
              Positioned.fromRect(
                rect: rect.inflate(2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.inverseSurface, width: 2),
                  ),
                ),
              ),
              Positioned(
                left: lx,
                top: ly,
                width: labelW,
                child: Material(
                  color: colors.inverseSurface,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: hit.color,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.onInverseSurface.withValues(alpha: 0.25)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hit.role.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: monoStyle(12.5, weight: FontWeight.w700, color: colors.onInverseSurface),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${hit.color.hex} · tone ${hit.color.tone} · ${hit.brightness.name}',
                                style: monoStyle(10.5, color: colors.onInverseSurface.withValues(alpha: 0.75)),
                              ),
                              if (partner != null)
                                Text(
                                  'with ${partner.label}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: monoStyle(10.5, color: colors.onInverseSurface.withValues(alpha: 0.6)),
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
        },
      ),
    );
  }
}
