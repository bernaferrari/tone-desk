import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:tone_desk/main.dart';
import 'package:tone_desk/model/color_math.dart';
import 'package:tone_desk/model/exporters.dart';
import 'package:tone_desk/model/recipe.dart';
import 'package:tone_desk/model/roles.dart';
import 'package:tone_desk/state/studio_cubit.dart';
import 'package:tone_desk/ui/chrome.dart';
import 'package:tone_desk/ui/controls.dart';
import 'package:tone_desk/ui/desk.dart';
import 'package:tone_desk/ui/export_board.dart';
import 'package:tone_desk/ui/scheme_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<StudioCubit> boot(WidgetTester tester, {Size viewport = const Size(1600, 960)}) async {
    tester.view.physicalSize = viewport;
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
      final face = find.descendant(of: button, matching: find.byType(Icon)).first;
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

  testWidgets('Tab reaches the toolbar and Space activates the focused button', (tester) async {
    final cubit = await boot(tester);
    final seed = cubit.state.recipe.seed;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.byType(ExportBoard), findsOneWidget);
    expect(cubit.state.recipe.seed, seed);
  });

  testWidgets('a focused rotary knob responds to arrow keys', (tester) async {
    final cubit = await boot(tester);
    final knob = find.byType(TickKnob).first;
    final face = find.descendant(of: knob, matching: find.byType(CustomPaint));
    Focus.of(tester.element(face)).requestFocus();
    await tester.pump();
    final before = cubit.state.recipe.vivid;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(cubit.state.recipe.vivid, lessThan(before));
  });

  testWidgets('the 320 px toolbar and export format are usable', (tester) async {
    final cubit = await boot(tester, viewport: const Size(320, 700));
    await tester.tap(find.byTooltip('Studio actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About Tone Desk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Export theme (E)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownMenu<ExportFormat>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSS').last);
    await tester.pumpAndSettle();
    expect(cubit.state.exportFormat, ExportFormat.css);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the custom color picker scrolls and saves in a short viewport', (tester) async {
    final cubit = await boot(tester);
    await tester.tap(find.byTooltip('Type a color'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(800, 380);
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    final reels = find.descendant(of: dialog, matching: find.byType(ColorReel));
    expect(reels, findsNWidgets(3));
    final chroma = reels.at(1);
    await tester.ensureVisible(chroma);
    await tester.pumpAndSettle();
    final before = tester.widget<ColorReel>(chroma).value;
    final scrollable = find.descendant(of: dialog, matching: find.byType(Scrollable)).first;
    final position = tester.state<ScrollableState>(scrollable).position;
    final offset = position.pixels;
    await tester.sendEventToBinding(
      PointerScrollEvent(position: tester.getCenter(chroma), scrollDelta: const Offset(0, -60)),
    );
    await tester.pumpAndSettle();
    expect(position.pixels, lessThan(offset));
    expect(tester.widget<ColorReel>(chroma).value, before);

    await tester.ensureVisible(chroma);
    final strip = find.descendant(of: chroma, matching: find.byType(CustomPaint)).first;
    Focus.of(tester.element(strip)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(tester.widget<ColorReel>(chroma).value, closeTo(before + 5, .01));

    final field = find.widgetWithText(TextField, 'Color value');
    await tester.ensureVisible(field);
    await tester.enterText(field, '#123456');
    await tester.pump();
    await tester.tap(find.text('Use color'));
    await tester.pumpAndSettle();
    expect(cubit.state.recipe.seed, const Color(0xFF123456));
    expect(tester.takeException(), isNull);
  });

  testWidgets('All colors includes foreground, fixed and utility roles', (tester) async {
    await boot(tester);
    await tester.tap(find.byTooltip('All colors (C)'));
    await tester.pumpAndSettle();
    final board = find.byType(SchemeBoard);
    final scrollable = find.descendant(of: board, matching: find.byType(Scrollable));
    for (final role in [Role.onPrimary, Role.onTertiaryFixedVariant, Role.shadow]) {
      final tile = find.descendant(of: board, matching: find.text(role.label));
      await tester.scrollUntilVisible(tile, 300, scrollable: scrollable);
      expect(tile.hitTestable(), findsOneWidget);
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
    List<BorderRadius> corners() =>
        tester.widgetList<ChannelStrip>(find.byType(ChannelStrip)).map((strip) => strip.radius).toList();
    void expectReadouts() {
      final angles = find.textContaining(RegExp(r'^\d+°$'));
      expect(angles, findsNWidgets(Channel.values.length));
      expect(find.textContaining(RegExp(r'^Hue \d+°$')), findsNothing);
      expect(find.textContaining(RegExp(r'^Chroma \d+$')), findsNothing);
      for (final channel in Channel.values) {
        expect(find.byTooltip('${channel.label} chroma'), findsOneWidget);
      }
      final primaryKnob = tester.getRect(find.byType(HueKnob).first);
      final primaryAngle = tester.getRect(angles.first);
      expect(primaryAngle.center.dx, closeTo(primaryKnob.center.dx, 0.01));
      expect(primaryAngle.top - primaryKnob.bottom, greaterThanOrEqualTo(8));
    }

    final columns = corners();
    expectReadouts();
    expect(columns.first.topLeft.x, greaterThan(columns.first.topRight.x));
    expect(columns.last.topRight.x, greaterThan(columns.last.topLeft.x));
    expect(columns[1].topLeft, columns.first.topRight);

    await tester.tap(find.byTooltip('Lay the channels down as rows'));
    await tester.pumpAndSettle();
    expect(cubit.state.mixerRows, isTrue);
    final rows = corners();
    expectReadouts();
    expect(rows.first.topLeft, columns.first.topLeft);
    expect(rows.first.bottomLeft, columns.first.topRight);
    expect(rows.last.bottomLeft, columns.last.topRight);

    final fader = find.byType(Fader).first;
    cubit.toggleMute(Channel.primary);
    await tester.ensureVisible(fader);
    await tester.pumpAndSettle();
    expect(tester.widget<Fader>(fader).semanticValue, '0');
    final box = tester.getRect(fader);
    await tester.dragFrom(box.centerLeft + const Offset(12, 0), Offset(box.width - 24, 0));
    await tester.pumpAndSettle();
    expect(cubit.state.recipe.mixOf(Channel.primary).muted, isFalse);
    expect(cubit.state.recipe.mixOf(Channel.primary).chroma, greaterThan(40));
    cubit.undo();
    await tester.pumpAndSettle();
    expect(cubit.state.recipe.mixOf(Channel.primary).muted, isTrue);

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

  testWidgets('the preview pause icon stays legible while switching styles', (tester) async {
    final cubit = await boot(tester);
    cubit.setSeed(swatches[2]);
    cubit.setVariant(Variant.content);
    await tester.pumpAndSettle();

    final pauseIcons = find.byIcon(Icons.pause_rounded).hitTestable();
    expect(pauseIcons, findsNWidgets(2));
    cubit.setVariant(Variant.fidelity);
    await tester.pump();
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      for (final icon in pauseIcons.evaluate()) {
        final fill = icon.findAncestorWidgetOfExactType<Material>()!.color!;
        final ink = Color.alphaBlend((icon.widget as Icon).color ?? IconTheme.of(icon).color!, fill);
        expect(
          contrastRatio(ink, fill),
          greaterThanOrEqualTo(3),
          reason: '${Theme.of(icon).brightness.name}, frame $frame, ink $ink on $fill',
        );
      }
    }
  });
}
