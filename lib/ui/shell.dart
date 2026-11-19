import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/studio_cubit.dart';
import 'chrome.dart';
import 'export_board.dart';
import 'scheme_board.dart';
import 'stage/stage.dart';
import 'tune_panel.dart';

const _wide = 1280.0;
const _medium = 960.0;

class const StudioShell() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): cubit.shuffle,
        const SingleActivator(LogicalKeyboardKey.space, shift: true): cubit.shuffleStyle,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): cubit.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): cubit.undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): cubit.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): cubit.redo,
        const SingleActivator(LogicalKeyboardKey.keyI): cubit.toggleInspecting,
        const SingleActivator(LogicalKeyboardKey.keyD): cubit.toggleBrightness,
        const SingleActivator(LogicalKeyboardKey.keyC): () => showColors(context),
        const SingleActivator(LogicalKeyboardKey.keyE): () => showExport(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                if (w >= _wide && constraints.maxHeight >= 640) return const _WideLayout();
                if (w >= _medium && constraints.maxHeight >= 600) return const _WideLayout(column: 344);
                return const _NarrowLayout();
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The steps on the left, the preview filling the rest.
class const _WideLayout({final double column = 380}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const _Header(),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SideColumn(width: column, children: const [ThemeControls()]),
                const SizedBox(width: 16),
                const Expanded(child: _Center()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class const _SideColumn({required final double width, required final List<Widget> children}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: _ScrollColumn(children: children),
  );
}

class const _NarrowLayout() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _ScrollColumn(
      padding: const EdgeInsets.all(12),
      children: [
        const _Header(compact: true),
        const SizedBox(height: 12),
        const Panel(padding: EdgeInsets.fromLTRB(12, 16, 12, 16), child: Stage(compact: true)),
        const SizedBox(height: 12),
        const ThemeControls(compact: true),
        const SizedBox(height: 32),
      ],
    );
  }
}

class const _ScrollColumn({required final List<Widget> children, final EdgeInsets padding = EdgeInsets.zero})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(padding: padding, children: children),
    );
  }
}

class const _Center() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Panel(padding: EdgeInsets.fromLTRB(22, 22, 22, 16), child: Stage());
  }
}

/// Every role and tonal palette, in a sheet over the studio.
void showColors(BuildContext context) => _showSheet(context, title: 'All colors', child: const SchemeBoard());

/// The theme as Flutter, CSS, Tailwind or design tokens.
void showExport(BuildContext context) => _showSheet(context, title: 'Export', child: const ExportBoard());

void _showSheet(BuildContext context, {required String title, required Widget child}) {
  final size = MediaQuery.sizeOf(context);
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: SizedBox(
        width: (size.width - 48).clamp(320.0, 1080.0),
        height: (size.height - 48).clamp(420.0, 880.0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(title, style: displayStyle(30)),
                  const Spacer(),
                  StudioIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close (Esc)',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Padding(padding: const EdgeInsets.only(right: 8), child: child),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class const _Header({final bool compact = false}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    final state = context.watch<StudioCubit>().state;
    final views = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StudioIconButton(icon: Icons.casino_outlined, tooltip: 'Surprise me (Space)', onTap: cubit.shuffle),
        const SizedBox(width: 6),
        PillButton(
          label: 'Export',
          dense: true,
          icon: Icons.code_rounded,
          tooltip: 'Code for Flutter, CSS and Tailwind (E)',
          onTap: () => showExport(context),
        ),
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StudioIconButton(icon: Icons.undo_rounded, tooltip: 'Undo (⌘Z)', onTap: state.canUndo ? cubit.undo : null),
        StudioIconButton(icon: Icons.redo_rounded, tooltip: 'Redo (⇧⌘Z)', onTap: state.canRedo ? cubit.redo : null),
        const SizedBox(width: 4),
        StudioIconButton(icon: Icons.palette_outlined, tooltip: 'All colors (C)', onTap: () => showColors(context)),
        StudioIconButton(
          icon: state.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          tooltip: state.isDark ? 'Light studio (D)' : 'Dark studio (D)',
          onTap: cubit.toggleBrightness,
        ),
        StudioIconButton(
          icon: Icons.info_outline_rounded,
          tooltip: 'About Tone Desk',
          onTap: () => _showAbout(context),
        ),
      ],
    );
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const FaderMark(size: 34),
        const SizedBox(width: 12),
        Text('Tone Desk', style: displayStyle(24)),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [brand, const Spacer(), actions]),
          const SizedBox(height: 12),
          Align(alignment: Alignment.centerRight, child: views),
        ],
      );
    }
    return SizedBox(
      height: 48,
      child: Row(
        children: [const SizedBox(width: 6), brand, const Spacer(), views, const SizedBox(width: 10), actions],
      ),
    );
  }
}

void _showAbout(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const FaderMark(size: 56),
      title: Text('Tone Desk', style: displayStyle(28)),
      content: SizedBox(
        width: 380,
        child: Text(
          'Make a Material 3 theme in three steps.\n\n'
          'Pick a color, choose how colorful it should be, then adjust how vivid it is, '
          'how tinted the surfaces are and how strong the contrast is. Need more? The '
          'mixer gives every tonal palette its own hue knob and chroma slider, and lets '
          'you set exact brand colors.\n\n'
          'Space surprises you, I inspects the preview, D flips light and dark, '
          'C shows every color, E exports.\n\n'
          'Tone Desk wears your theme while you make it, the way Color Studio, '
          'where it started in 2019, always did.',
          style: TextStyle(height: 1.45, color: colors.onSurfaceVariant),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => launchUrl(Uri.parse('https://github.com/bernaferrari/tone-desk')),
          child: const Text('Source on GitHub'),
        ),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Mix')),
      ],
    ),
  );
}
