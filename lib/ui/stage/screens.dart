import 'package:material_ui/material_ui.dart';

import '../../model/roles.dart';
import 'probe.dart';

enum MockScreen(final String label, final IconData icon) {
  wrapped('Wrapped', Icons.graphic_eq_rounded),
  profile('Profile', Icons.person_outline_rounded),
  trip('Trip', Icons.flight_takeoff_rounded),
  chat('Chat', Icons.chat_bubble_outline_rounded),
  parts('Parts', Icons.widgets_outlined);

  Widget build() => switch (this) {
    wrapped => const WrappedScreen(),
    profile => const ProfileScreen(),
    trip => const TripScreen(),
    chat => const ChatScreen(),
    parts => const PartsScreen(),
  };
}

ColorScheme _c(BuildContext context) => Theme.of(context).colorScheme;

/// A round badge. Unlike CircleAvatar it doesn't animate its color, which
/// would freeze in the thumbnails, where tickers are off.
class const _Avatar({final double radius = 20, required final Color color, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: radius * 2,
    height: radius * 2,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: child,
  );
}

TextTheme _t(BuildContext context) => Theme.of(context).textTheme;
double _top(BuildContext context) => MediaQuery.paddingOf(context).top;
double _bottom(BuildContext context) => MediaQuery.paddingOf(context).bottom;

/// A screen's scrolling body. It starts below the status bar so content never
/// slides under the clock, and ends clear of the home indicator.
class const _ScreenList({
  final double top = 0,
  final double bottom = 16,

  /// False when something else, like a navigation bar, sits below the list.
  final bool reachesBottom = true,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: _top(context)),
    child: ListView(
      padding: EdgeInsets.fromLTRB(16, top, 16, bottom + (reachesBottom ? _bottom(context) : 0)),
      physics: const ClampingScrollPhysics(),
      children: children,
    ),
  );
}

/// "Your year, wrapped": a nod to the original Color Studio preview.
class const WrappedScreen() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    final t = _t(context);
    return Column(
      children: [
        Expanded(
          child: _ScreenList(
            reachesBottom: false,
            top: 4,
            bottom: 16,
            children: [
              Row(
                children: [
                  Probe(
                    role: Role.tertiaryContainer,
                    child: _Avatar(
                      radius: 18,
                      color: c.tertiaryContainer,
                      child: Text(
                        'BF',
                        style: TextStyle(color: c.onTertiaryContainer, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Probe(
                    role: Role.onSurface,
                    child: Text('Good evening', style: t.titleMedium),
                  ),
                  const Spacer(),
                  Probe(
                    role: Role.onSurfaceVariant,
                    child: IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Probe(
                role: Role.primaryContainer,
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(color: c.primaryContainer, borderRadius: BorderRadius.circular(28)),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned(
                        right: -46,
                        top: -70,
                        child: Probe(
                          role: Role.primary,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 92,
                        top: 18,
                        child: Probe(
                          role: Role.tertiary,
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(color: c.tertiary, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(),
                            Probe(
                              role: Role.onPrimaryContainer,
                              child: Text(
                                'Your 2026,\nwrapped.',
                                style: t.headlineMedium?.copyWith(
                                  color: c.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                  height: 1.05,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Dig into the music that made your year.',
                              style: t.bodyMedium?.copyWith(color: c.onPrimaryContainer),
                            ),
                            const SizedBox(height: 14),
                            Probe(
                              role: Role.primary,
                              child: FilledButton(onPressed: () {}, child: const Text('Take a look')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      role: Role.secondaryContainer,
                      background: c.secondaryContainer,
                      ink: c.onSecondaryContainer,
                      label: 'Minutes',
                      value: '48,213',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      role: Role.tertiaryContainer,
                      background: c.tertiaryContainer,
                      ink: c.onTertiaryContainer,
                      label: 'Top genre',
                      value: 'Bossa',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Top songs', style: t.titleMedium),
              const SizedBox(height: 4),
              for (final (i, title, artist, role) in [
                (1, 'Águas de Março', 'Elis & Tom', Role.primary),
                (2, 'Midnight Static', 'The Faders', Role.tertiary),
                (3, 'Tonal Spot', 'Material Girls', Role.secondary),
              ])
                Probe(
                  role: Role.surface,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Probe(
                      role: role,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: role.of(c), borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          '$i',
                          style: TextStyle(color: role.partner!.of(c), fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    title: Text(title),
                    subtitle: Probe(role: Role.onSurfaceVariant, child: Text(artist)),
                    trailing: Icon(Icons.more_vert_rounded, color: c.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
        Probe(
          role: Role.surfaceContainerHighest,
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: c.tertiary, borderRadius: BorderRadius.circular(9)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Midnight Static', style: t.labelLarge),
                          Text('The Faders', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_rounded), color: c.primary),
                    Probe(
                      role: Role.primary,
                      child: IconButton.filled(
                        onPressed: () {},
                        // Keep the glyph in sync with the fill as the preview theme animates.
                        icon: Icon(Icons.pause_rounded, color: c.onPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Probe(
                  role: Role.primary,
                  child: LinearProgressIndicator(value: 0.42, borderRadius: BorderRadius.circular(4)),
                ),
              ],
            ),
          ),
        ),
        Probe(
          role: Role.surfaceContainer,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(padding: EdgeInsets.only(bottom: _bottom(context) * 0.4)),
            child: NavigationBar(
              height: 60,
              selectedIndex: 0,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'Explore'),
                NavigationDestination(icon: Icon(Icons.library_music_outlined), label: 'Library'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class const _StatCard({
  required final Role role,
  required final Color background,
  required final Color ink,
  required final String label,
  required final String value,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    return Probe(
      role: role,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(22)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.labelMedium?.copyWith(color: ink)),
            const SizedBox(height: 4),
            Text(
              value,
              style: t.headlineSmall?.copyWith(color: ink, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// A contact card, after the original app's profile preview.
class const ProfileScreen() extends StatefulWidget {
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState() extends State<ProfileScreen> {
  bool _location = true;
  bool _quiet = false;

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    final t = _t(context);
    return _ScreenList(
      top: 0,
      bottom: 16,
      children: [
        Row(
          children: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.arrow_back_rounded)),
            Text('Contacts', style: t.titleLarge),
            const Spacer(),
            IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded)),
          ],
        ),
        const SizedBox(height: 8),
        Probe(
          role: Role.surfaceContainerLow,
          child: Card(
            elevation: 0,
            color: c.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  Probe(
                    role: Role.primary,
                    child: _Avatar(
                      radius: 44,
                      color: c.primary,
                      child: Text(
                        'BF',
                        style: t.headlineMedium?.copyWith(color: c.onPrimary, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Bernardo Ferrari', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Probe(
                    role: Role.onSurfaceVariant,
                    child: Text('Designer · Porto Alegre', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final (icon, label) in [
                        (Icons.chat_bubble_outline_rounded, 'Message'),
                        (Icons.call_outlined, 'Audio'),
                        (Icons.videocam_outlined, 'Video'),
                      ])
                        Column(
                          children: [
                            Probe(
                              role: Role.secondaryContainer,
                              child: IconButton.filledTonal(
                                onPressed: () {},
                                iconSize: 26,
                                padding: const EdgeInsets.all(16),
                                icon: Icon(icon),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(label, style: t.labelMedium),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: Probe(
                      role: Role.primary,
                      child: FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        child: const Text('View profile'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('Recent', style: t.titleSmall?.copyWith(color: c.primary)),
        ),
        for (final (title, time, count) in [
          ('Missed call', 'Today, 9:12', 2),
          ('Shared a palette', 'Yesterday', 0),
          ('“Love the plum dark mode”', 'Mon', 5),
        ])
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Probe(
              role: Role.tertiaryContainer,
              child: _Avatar(
                color: c.tertiaryContainer,
                child: Icon(Icons.history_rounded, size: 20, color: c.onTertiaryContainer),
              ),
            ),
            title: Text(title),
            subtitle: Text(time),
            trailing: count == 0
                ? null
                : Probe(
                    role: Role.error,
                    child: Badge(label: Text('$count'), largeSize: 20),
                  ),
          ),
        const Divider(height: 24),
        Probe(
          role: Role.primary,
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Share my location'),
            value: _location,
            onChanged: (v) => setState(() => _location = v),
          ),
        ),
        Probe(
          role: Role.surfaceContainerHighest,
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text('Do not disturb'),
            value: _quiet,
            onChanged: (v) => setState(() => _quiet = v),
          ),
        ),
      ],
    );
  }
}

/// "Plan a trip", the third classic preview.
class const TripScreen() extends StatefulWidget {
  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState() extends State<TripScreen> {
  String _mode = 'Flights';
  int _day = 1;

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    final t = _t(context);
    return Stack(
      children: [
        _ScreenList(
          top: 4,
          bottom: 90,
          children: [
            Probe(
              role: Role.onSurface,
              child: Text('Plan a trip', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 12),
            Probe(
              role: Role.surfaceContainerHigh,
              child: SearchBar(
                hintText: 'Where to?',
                elevation: const WidgetStatePropertyAll(0),
                leading: const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.search_rounded)),
                trailing: [
                  Probe(
                    role: Role.primary,
                    child: _Avatar(
                      radius: 16,
                      color: c.primary,
                      child: Icon(Icons.tune_rounded, size: 18, color: c.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Probe(
              role: Role.secondaryContainer,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'Flights', label: Text('Flights'), icon: Icon(Icons.flight_rounded)),
                  ButtonSegment(value: 'Hotels', label: Text('Hotels'), icon: Icon(Icons.hotel_rounded)),
                  ButtonSegment(value: 'Rental', label: Text('Rental'), icon: Icon(Icons.directions_car_rounded)),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ),
            const SizedBox(height: 18),
            Text('Trending', style: t.titleMedium),
            const SizedBox(height: 10),
            SizedBox(
              height: 168,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _Destination(
                    city: 'Lisbon',
                    country: 'Portugal',
                    a: c.primary,
                    b: c.tertiaryContainer,
                    role: Role.primary,
                  ),
                  _Destination(
                    city: 'Kyoto',
                    country: 'Japan',
                    a: c.tertiary,
                    b: c.primaryContainer,
                    role: Role.tertiary,
                  ),
                  _Destination(
                    city: 'Oaxaca',
                    country: 'Mexico',
                    a: c.secondary,
                    b: c.errorContainer,
                    role: Role.secondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('When', style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, day) in ['Fri 12', 'Sat 13', 'Sun 14', 'Mon 15'].indexed)
                  Probe(
                    role: Role.secondaryContainer,
                    child: FilterChip(
                      label: Text(day),
                      selected: _day == i,
                      onSelected: (_) => setState(() => _day = i),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Probe(
              role: Role.surfaceContainerHighest,
              child: Card.filled(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('POA → LIS', style: t.labelLarge?.copyWith(color: c.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Probe(
                              role: Role.onSurface,
                              child: Text('From \$412', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ),
                      Probe(
                        role: Role.secondaryContainer,
                        child: FilledButton.tonal(onPressed: () {}, child: const Text('Details')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16 + _bottom(context),
          child: Probe(
            role: Role.primaryContainer,
            child: FloatingActionButton.extended(
              onPressed: () {},
              elevation: 2,
              icon: const Icon(Icons.explore_rounded),
              label: const Text('Explore'),
            ),
          ),
        ),
      ],
    );
  }
}

class const _Destination({
  required final String city,
  required final String country,
  required final Color a,
  required final Color b,
  required final Role role,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    final ink = role.partner!.of(_c(context));
    return Probe(
      role: role,
      child: Container(
        width: 132,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [b, a]),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Icon(Icons.favorite_border_rounded, color: ink, size: 20),
            ),
            const Spacer(),
            Text(
              city,
              style: t.titleLarge?.copyWith(color: ink, fontWeight: FontWeight.w800),
            ),
            Text(country, style: t.bodySmall?.copyWith(color: ink)),
          ],
        ),
      ),
    );
  }
}

class const ChatScreen() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    final t = _t(context);

    Widget bubble(String text, {required bool mine, Role? role}) {
      final r = role ?? (mine ? Role.primary : Role.surfaceContainerHigh);
      final bg = r.of(c);
      final ink = r == Role.surfaceContainerHigh ? c.onSurface : r.partner!.of(c);
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Probe(
          role: r,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 250),
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(mine ? 20 : 6),
                bottomRight: Radius.circular(mine ? 6 : 20),
              ),
            ),
            child: Text(text, style: t.bodyMedium?.copyWith(color: ink)),
          ),
        ),
      );
    }

    return Column(
      children: [
        Probe(
          role: Role.surfaceContainer,
          child: Container(
            color: c.surfaceContainer,
            padding: EdgeInsets.fromLTRB(4, 4 + _top(context), 12, 10),
            child: Row(
              children: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.arrow_back_rounded)),
                Probe(
                  role: Role.secondaryContainer,
                  child: _Avatar(
                    color: c.secondaryContainer,
                    child: Text(
                      'MA',
                      style: TextStyle(color: c.onSecondaryContainer, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Marina', style: t.titleMedium),
                      Probe(
                        role: Role.tertiary,
                        child: Text('online', style: t.bodySmall?.copyWith(color: c.tertiary)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.videocam_outlined, color: c.onSurfaceVariant),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(14),
            physics: const ClampingScrollPhysics(),
            children: [
              Center(
                child: Probe(
                  role: Role.surfaceContainerHighest,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('Today', style: t.labelSmall?.copyWith(color: c.onSurfaceVariant)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              bubble('did you ship the new theme?', mine: false),
              bubble('almost. mixing the neutrals now', mine: true),
              bubble('make the dark mode a little warmer 🙏', mine: false),
              bubble('done. nudged the neutral hue to 30°', mine: true),
              Align(
                alignment: Alignment.centerRight,
                child: Probe(
                  role: Role.tertiaryContainer,
                  child: Container(
                    margin: const EdgeInsets.only(top: 2, right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: c.tertiaryContainer, borderRadius: BorderRadius.circular(99)),
                    child: Text('🔥 2', style: t.labelMedium?.copyWith(color: c.onTertiaryContainer)),
                  ),
                ),
              ),
              bubble('it looks so good', mine: false),
              bubble('Theme exported · Flutter + Tailwind', mine: true, role: Role.secondaryContainer),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Probe(
                  role: Role.primary,
                  child: Icon(Icons.done_all_rounded, size: 16, color: c.primary),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 4, 12, 8 + _bottom(context)),
          child: Row(
            children: [
              Expanded(
                child: Probe(
                  role: Role.surfaceContainerHighest,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: c.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('Message', style: t.bodyLarge?.copyWith(color: c.onSurfaceVariant)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Probe(
                role: Role.primary,
                child: IconButton.filled(
                  onPressed: () {},
                  iconSize: 22,
                  padding: const EdgeInsets.all(12),
                  icon: const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A sheet of stock Material 3 components.
class const PartsScreen() extends StatefulWidget {
  @override
  State<PartsScreen> createState() => _PartsScreenState();
}

class _PartsScreenState() extends State<PartsScreen> {
  bool _switch = true;
  bool _check = true;
  double _slider = 0.6;
  bool _filter = true;

  @override
  Widget build(BuildContext context) {
    final c = _c(context);
    final t = _t(context);

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(text.toUpperCase(), style: t.labelSmall?.copyWith(color: c.onSurfaceVariant, letterSpacing: 1.2)),
    );

    return _ScreenList(
      top: 0,
      bottom: 16,
      children: [
        Text('Components', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        label('Buttons'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Probe(
              role: Role.primary,
              child: FilledButton(onPressed: () {}, child: const Text('Filled')),
            ),
            Probe(
              role: Role.secondaryContainer,
              child: FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
            ),
            Probe(
              role: Role.outline,
              child: OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
            ),
            Probe(
              role: Role.surfaceContainerLow,
              child: ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
            ),
            Probe(
              role: Role.primary,
              child: TextButton(onPressed: () {}, child: const Text('Text')),
            ),
          ],
        ),
        label('Selection'),
        Row(
          children: [
            Probe(
              role: Role.primary,
              child: Switch(value: _switch, onChanged: (v) => setState(() => _switch = v)),
            ),
            const SizedBox(width: 8),
            Probe(
              role: Role.surfaceContainerHighest,
              child: Switch(value: !_switch, onChanged: (v) => setState(() => _switch = !v)),
            ),
            const SizedBox(width: 4),
            Probe(
              role: Role.primary,
              child: Checkbox(value: _check, onChanged: (v) => setState(() => _check = v ?? false)),
            ),
            Probe(
              role: Role.error,
              child: Checkbox(value: true, isError: true, onChanged: (_) {}),
            ),
          ],
        ),
        Probe(
          role: Role.primary,
          child: Slider(value: _slider, onChanged: (v) => setState(() => _slider = v)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Probe(
              role: Role.secondaryContainer,
              child: FilterChip(
                label: const Text('Filter'),
                selected: _filter,
                onSelected: (v) => setState(() => _filter = v),
              ),
            ),
            Probe(
              role: Role.outlineVariant,
              child: ActionChip(avatar: const Icon(Icons.bolt_rounded), label: const Text('Assist'), onPressed: () {}),
            ),
            Probe(
              role: Role.outlineVariant,
              child: InputChip(label: const Text('Input'), onDeleted: () {}),
            ),
          ],
        ),
        label('Text field'),
        Probe(
          role: Role.outline,
          child: const TextField(
            decoration: InputDecoration(
              labelText: 'Theme name',
              hintText: 'Plum & peach',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Probe(
          role: Role.error,
          child: const TextField(
            decoration: InputDecoration(
              labelText: 'Hex',
              errorText: 'That is not a color',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        label('Progress'),
        Row(
          children: [
            Probe(
              role: Role.primary,
              child: const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(value: 0.7)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Probe(role: Role.primary, child: const LinearProgressIndicator(value: 0.4)),
            ),
          ],
        ),
        label('Feedback'),
        Probe(
          role: Role.inverseSurface,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
            decoration: BoxDecoration(color: c.inverseSurface, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(
                  child: Text('Theme saved', style: TextStyle(color: c.onInverseSurface)),
                ),
                Probe(
                  role: Role.inversePrimary,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(foregroundColor: c.inversePrimary),
                    child: const Text('Undo'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Probe(
          role: Role.surfaceContainerHigh,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(28)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.palette_outlined, color: c.secondary),
                const SizedBox(height: 10),
                Text('Discard this mix?', style: t.headlineSmall),
                const SizedBox(height: 6),
                Text('Your channels go back to unity.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () {}, child: const Text('Cancel')),
                    Probe(
                      role: Role.error,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(foregroundColor: c.error),
                        child: const Text('Discard'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        label('Fixed accents'),
        Row(
          children: [
            for (final (role, on) in [
              (Role.primaryFixed, Role.onPrimaryFixed),
              (Role.secondaryFixed, Role.onSecondaryFixed),
              (Role.tertiaryFixed, Role.onTertiaryFixed),
            ])
              Expanded(
                child: Probe(
                  role: role,
                  child: Container(
                    height: 52,
                    margin: const EdgeInsets.only(right: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: role.of(c), borderRadius: BorderRadius.circular(14)),
                    child: Text(
                      'Fixed',
                      style: TextStyle(color: on.of(c), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
