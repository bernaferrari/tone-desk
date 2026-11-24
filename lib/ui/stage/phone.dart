import 'package:material_ui/material_ui.dart';

import '../../model/roles.dart';
import 'probe.dart';

const phoneSize = Size(360, 760);

/// Screens draw under the status bar and pad their own content by this much.
const statusBarHeight = 38.0;

/// Room the home indicator takes at the bottom, which screens pad by too.
const homeIndicatorHeight = 20.0;

/// A phone bezel around a mock screen, drawn at real size and scaled to fit.
class const PhoneFrame({super.key, required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FittedBox(
      alignment: Alignment.topCenter,
      child: Container(
        width: phoneSize.width + 20,
        height: phoneSize.height + 20,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF101114),
          borderRadius: BorderRadius.circular(54),
          border: Border.all(color: const Color(0xFF2C2E33), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 40, offset: const Offset(0, 18)),
          ],
        ),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(44),
            child: Probe(
              role: Role.surface,
              child: Material(
                color: colors.surface,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          padding: const EdgeInsets.only(top: statusBarHeight, bottom: homeIndicatorHeight),
                          viewPadding: const EdgeInsets.only(top: statusBarHeight, bottom: homeIndicatorHeight),
                        ),
                        child: child,
                      ),
                    ),
                    const Positioned(top: 0, left: 0, right: 0, child: IgnorePointer(child: _StatusBar())),
                    const Positioned(left: 0, right: 0, bottom: 0, child: IgnorePointer(child: _HomeIndicator())),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class const _StatusBar() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: statusBarHeight,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 10, 24, 0),
            child: SizedBox(
              height: 22,
              child: Row(
                children: [
                  Text(
                    '9:41',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const Spacer(),
                  Icon(Icons.signal_cellular_alt_rounded, size: 16, color: ink),
                  const SizedBox(width: 4),
                  Icon(Icons.wifi_rounded, size: 16, color: ink),
                  const SizedBox(width: 4),
                  Icon(Icons.battery_full_rounded, size: 16, color: ink),
                ],
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(color: Color(0xFF101114), shape: BoxShape.circle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class const _HomeIndicator() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: homeIndicatorHeight,
      child: Center(
        child: Container(
          width: 110,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
