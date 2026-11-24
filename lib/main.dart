import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'model/scheme_engine.dart';
import 'state/studio_cubit.dart';
import 'ui/chrome.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (cubit, _) = await (StudioCubit.open(), preloadFonts()).wait;
  runApp(ToneDeskApp(cubit: cubit));
}

class const ToneDeskApp({super.key, required final StudioCubit cubit}) extends StatefulWidget {
  @override
  State<ToneDeskApp> createState() => _ToneDeskAppState();
}

class _ToneDeskAppState() extends State<ToneDeskApp> {
  late final _liveColors = ValueNotifier<ColorScheme>(
    resolveScheme(widget.cubit.state.recipe, widget.cubit.state.brightness).colors,
  );

  @override
  void dispose() {
    _liveColors.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.cubit,
      child: LiveColorsScope(
        colors: _liveColors,
        child: BlocListener<StudioCubit, StudioState>(
          listenWhen: (a, b) => a.recipe != b.recipe || a.brightness != b.brightness,
          listener: (_, state) => _liveColors.value = resolveScheme(state.recipe, state.brightness).colors,
          child: BlocBuilder<StudioCubit, StudioState>(
            // Live chrome paints through LiveColorsScope while scrubbing; the
            // full MaterialApp theme catches up cleanly on release.
            buildWhen: (a, b) => !b.scrubbing && (a.recipe != b.recipe || a.brightness != b.brightness || a.scrubbing),
            builder: (context, state) {
              final scheme = resolveScheme(state.recipe, state.brightness);
              return MaterialApp(
                title: 'Tone Desk',
                debugShowCheckedModeBanner: false,
                theme: studioTheme(scheme.colors),
                themeAnimationDuration: const Duration(milliseconds: 160),
                home: const StudioShell(),
              );
            },
          ),
        ),
      ),
    );
  }
}
