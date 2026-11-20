import 'package:tone_desk/main.dart';
import 'package:tone_desk/model/recipe.dart';
import 'package:tone_desk/state/studio_cubit.dart';
import 'package:tone_desk/ui/chrome.dart';
import 'package:tone_desk/ui/controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<StudioCubit> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = StudioCubit();
    await tester.pumpWidget(ToneDeskApp(cubit: cubit));
    await tester.pumpAndSettle();
    return cubit;
  }

  testWidgets('the three steps are all there is at first', (tester) async {
    await boot(tester);
    expect(find.text('Pick a color'), findsOneWidget);
    expect(find.text('How colorful?'), findsOneWidget);
    expect(find.text('Adjust'), findsOneWidget);
    expect(find.text('Mixer'), findsNothing);
  });

  testWidgets('About keeps the mark square and returns to the studio', (tester) async {
    await boot(tester);
    await tester.tap(find.byTooltip('About Tone Desk'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    final mark = find.descendant(of: dialog, matching: find.byType(FaderMark));
    final title = find.descendant(of: dialog, matching: find.text('Tone Desk'));
    expect(tester.getSize(mark), const Size.square(44));
    expect(tester.getRect(mark).right, lessThan(tester.getRect(title).left));
    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  });

  testWidgets('round buttons keep their size while held', (tester) async {
    await boot(tester);
    for (final tooltip in ['Surprise me (Space)', 'Use a photo']) {
      final button = find.byTooltip(tooltip);
      final face = find.descendant(of: button, matching: find.byType(AnimatedContainer)).first;
      final bounds = tester.getRect(face);
      final press = await tester.startGesture(bounds.center);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getRect(face), bounds);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(face), bounds);
      await press.cancel();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('rotary knobs keep their size while dragged', (tester) async {
    final cubit = await boot(tester);
    cubit.setMixerOpen(true);
    await tester.pumpAndSettle();

    for (final type in [TickKnob, HueKnob]) {
      final knob = find.byType(type).first;
      await tester.ensureVisible(knob);
      await tester.pumpAndSettle();
      final face = find.descendant(of: knob, matching: find.byType(CustomPaint));
      final bounds = tester.getRect(face);
      final drag = await tester.startGesture(bounds.center);
      final recipe = cubit.state.recipe;
      await drag.moveBy(const Offset(-40, 0));
      await drag.moveBy(const Offset(-12, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getRect(face), bounds);
      expect(cubit.state.recipe, isNot(recipe));
      await drag.up();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the colorful strip runs from gray to wild', (tester) async {
    final cubit = await boot(tester);
    final strip = find.byTooltip('Gray · Monochrome');
    await tester.tap(strip);
    await tester.pumpAndSettle();
    expect(cubit.state.recipe.variant.mood, 'Gray');
    expect(find.textContaining('Gray.', findRichText: true), findsOneWidget);
    await tester.tap(find.byTooltip('Wild · Fruit salad'));
    await tester.pumpAndSettle();
    expect(cubit.state.recipe.variant.mood, 'Wild');
  });

  testWidgets('only the old and new picks move as the colorful strip changes', (tester) async {
    final cubit = await boot(tester);
    final first = find.byTooltip('Gray · Monochrome');
    final last = find.byTooltip('Wild · Fruit salad');
    final left = tester.getRect(first).left;
    final right = tester.getRect(last).right;
    final width = tester.getSize(last).width;
    for (final v in [Variant.fidelity, Variant.vibrant, Variant.expressive, Variant.neutral]) {
      cubit.setVariant(v);
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getRect(first).left, closeTo(left, 0.01));
        expect(tester.getRect(last).right, closeTo(right, 0.01));
        expect(tester.getSize(last).width, closeTo(width, 0.01));
      }
    }
    await tester.pumpAndSettle();
  });

  testWidgets('more options opens the mixer, done folds it away', (tester) async {
    final cubit = await boot(tester);
    await tester.ensureVisible(find.text('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    expect(cubit.state.mixerOpen, isTrue);
    expect(find.text('Mixer'), findsOneWidget);
    expect(find.text('Reset'), findsNothing);

    cubit.toggleMute(Channel.secondary);
    await tester.pumpAndSettle();
    expect(find.text('Reset'), findsOneWidget);

    await tester.ensureVisible(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(cubit.state.mixerOpen, isFalse);
  });

  testWidgets('the mixer lays its channels down as rows, and back', (tester) async {
    final cubit = await boot(tester);
    cubit.setMixerOpen(true);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lay the channels down as rows'));
    await tester.pumpAndSettle();
    expect(cubit.state.mixerRows, isTrue);

    final fader = find.byType(Fader).first;
    await tester.ensureVisible(fader);
    await tester.pumpAndSettle();
    final box = tester.getRect(fader);
    await tester.dragFrom(box.centerLeft + const Offset(12, 0), Offset(box.width - 24, 0));
    await tester.pumpAndSettle();
    expect(cubit.state.recipe.mixOf(Channel.primary).chroma, greaterThan(40));

    await tester.ensureVisible(find.byTooltip('Stand the channels up'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Stand the channels up'));
    await tester.pumpAndSettle();
    expect(cubit.state.mixerRows, isFalse);
  });

  testWidgets('space shuffles and undo brings the seed back', (tester) async {
    final cubit = await boot(tester);
    final before = cubit.state.recipe.seed;
    cubit.shuffle();
    await tester.pumpAndSettle();
    expect(cubit.state.recipe.seed, isNot(before));
    cubit.undo();
    await tester.pumpAndSettle();
    expect(cubit.state.recipe.seed, before);
    expect(swatches, contains(before));
  });

  testWidgets('the parts preview chips toggle, inspecting or not', (tester) async {
    final cubit = await boot(tester);
    await tester.tap(find.byTooltip('Parts'));
    await tester.pumpAndSettle();
    final chip = find.byType(FilterChip).first;
    bool selected() => tester.widget<FilterChip>(chip).selected;
    for (final inspecting in [false, true]) {
      if (cubit.state.inspecting != inspecting) cubit.toggleInspecting();
      await tester.pumpAndSettle();
      final before = selected();
      await tester.tap(find.descendant(of: chip, matching: find.text('Filter')));
      await tester.pumpAndSettle();
      expect(selected(), !before);
    }
  });
}
