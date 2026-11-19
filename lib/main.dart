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

class const ToneDeskApp({super.key, required final StudioCubit cubit}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cubit,
      child: BlocBuilder<StudioCubit, StudioState>(
        buildWhen: (a, b) => a.recipe != b.recipe || a.brightness != b.brightness,
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
    );
  }
}
