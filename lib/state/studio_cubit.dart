import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/color_math.dart';
import '../model/exporters.dart';
import '../model/recipe.dart';

class const StudioState({
  required final ThemeRecipe recipe,
  final Brightness brightness = Brightness.light,
  final ExportFormat exportFormat = ExportFormat.flutter,
  final bool inspecting = false,

  /// Shows every channel strip instead of the three simple knobs.
  final bool mixerOpen = false,

  /// The channel the inspector last pointed at, to light up on the desk.
  final Channel? spotlight,
  final int spotlightTick = 0,
  final List<ThemeRecipe> undoStack = const [],
  final List<ThemeRecipe> redoStack = const [],
}) extends Equatable {
  bool get isDark => brightness == Brightness.dark;
  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  StudioState copyWith({
    ThemeRecipe? recipe,
    Brightness? brightness,
    ExportFormat? exportFormat,
    bool? inspecting,
    bool? mixerOpen,
    Channel? Function()? spotlight,
    int? spotlightTick,
    List<ThemeRecipe>? undoStack,
    List<ThemeRecipe>? redoStack,
  }) => StudioState(
    recipe: recipe ?? this.recipe,
    brightness: brightness ?? this.brightness,
    exportFormat: exportFormat ?? this.exportFormat,
    inspecting: inspecting ?? this.inspecting,
    mixerOpen: mixerOpen ?? this.mixerOpen,
    spotlight: spotlight != null ? spotlight() : this.spotlight,
    spotlightTick: spotlightTick ?? this.spotlightTick,
    undoStack: undoStack ?? this.undoStack,
    redoStack: redoStack ?? this.redoStack,
  );

  @override
  List<Object?> get props => [
    recipe,
    brightness,
    exportFormat,
    inspecting,
    mixerOpen,
    spotlight,
    spotlightTick,
    undoStack,
    redoStack,
  ];
}

class StudioCubit({StudioState? initial, final SharedPreferencesAsync? _prefs}) extends Cubit<StudioState> {
  this : super(initial ?? StudioState(recipe: starters[1]));

  static const _storageKey = 'studio.v3';
  static const _maxHistory = 60;

  ThemeRecipe? _scrubStart;
  final _rng = math.Random();

  static Future<StudioCubit> open() async {
    final prefs = SharedPreferencesAsync();
    StudioState? restored;
    try {
      final raw = await prefs.getString(_storageKey);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, Object?>;
        final recipe = ThemeRecipe.fromJson(json['recipe'] as Map<String, Object?>);
        if (recipe != null) {
          restored = StudioState(recipe: recipe, brightness: json['dark'] == true ? Brightness.dark : Brightness.light);
        }
      }
    } catch (_) {
      // A broken save should never keep the studio from opening.
    }
    return StudioCubit(initial: restored, prefs: prefs);
  }

  @override
  void onChange(Change<StudioState> change) {
    super.onChange(change);
    final prev = change.currentState;
    final next = change.nextState;
    if (_scrubStart == null && (prev.recipe != next.recipe || prev.brightness != next.brightness)) {
      _save(next);
    }
  }

  void _save(StudioState s) =>
      unawaited(_prefs?.setString(_storageKey, jsonEncode({'recipe': s.recipe.toJson(), 'dark': s.isDark})));

  // Recipe edits.

  void _commit(ThemeRecipe next, {bool live = false}) {
    if (next == state.recipe) return;
    if (live && _scrubStart != null) {
      emit(state.copyWith(recipe: next));
      return;
    }
    emit(state.copyWith(recipe: next, undoStack: _push(state.undoStack, state.recipe), redoStack: const []));
  }

  /// Starts a drag: the whole gesture becomes one undo step.
  void beginScrub() => _scrubStart ??= state.recipe;

  void endScrub() {
    final start = _scrubStart;
    _scrubStart = null;
    if (start == null || start == state.recipe) return;
    emit(state.copyWith(undoStack: _push(state.undoStack, start), redoStack: const []));
    _save(state);
  }

  void setSeed(Color seed, {bool live = false}) => _commit(
    state.recipe.copyWith(seed: seed, name: () => null),
    live: live,
  );

  void setVariant(Variant variant) => _commit(state.recipe.copyWith(variant: variant));

  void setContrast(double contrast, {bool live = false}) =>
      _commit(state.recipe.copyWith(contrast: contrast.clamp(-1.0, 1.0)), live: live);

  void setVivid(double value, {bool live = false}) => _commit(
    state.recipe.copyWith(vivid: value.clamp(ThemeRecipe.vividRange.$1, ThemeRecipe.vividRange.$2)),
    live: live,
  );

  void setTint(double value, {bool live = false}) =>
      _commit(state.recipe.copyWith(tint: value.clamp(ThemeRecipe.tintRange.$1, ThemeRecipe.tintRange.$2)), live: live);

  void setChannelHue(Channel channel, double? hue, {bool live = false}) => _commit(
    state.recipe.withMix(channel, state.recipe.mixOf(channel).withHue(hue == null ? null : hue % 360)),
    live: live,
  );

  void setChannelChroma(Channel channel, double? chroma, {bool live = false}) => _commit(
    state.recipe.withMix(channel, state.recipe.mixOf(channel).withChroma(chroma?.clamp(0.0, channel.maxChroma))),
    live: live,
  );

  /// Plugs an exact color into a channel: its hue and chroma drive the palette.
  void plugChannel(Channel channel, Color color) {
    final hct = Hct.fromInt(color.toARGB32());
    _commit(state.recipe.withMix(channel, ChannelMix(hue: hct.hue, chroma: hct.chroma)));
  }

  void toggleMute(Channel channel) {
    final mix = state.recipe.mixOf(channel);
    _commit(state.recipe.withMix(channel, mix.withMuted(!mix.muted)));
  }

  void resetChannel(Channel channel) => _commit(state.recipe.withMix(channel, ChannelMix.unity));

  void resetMix() => _commit(state.recipe.copyWith(mix: const {}));

  void loadRecipe(ThemeRecipe recipe) => _commit(recipe);

  void shuffle() {
    _commit(state.recipe.copyWith(seed: randomSeed(_rng)));
  }

  void shuffleStyle() {
    final others = styles.where((v) => v != state.recipe.variant).toList();
    setVariant(others[_rng.nextInt(others.length)]);
  }

  void undo() {
    if (!state.canUndo) return;
    emit(
      state.copyWith(
        recipe: state.undoStack.last,
        undoStack: state.undoStack.sublist(0, state.undoStack.length - 1),
        redoStack: [...state.redoStack, state.recipe],
      ),
    );
  }

  void redo() {
    if (!state.canRedo) return;
    emit(
      state.copyWith(
        recipe: state.redoStack.last,
        redoStack: state.redoStack.sublist(0, state.redoStack.length - 1),
        undoStack: _push(state.undoStack, state.recipe),
      ),
    );
  }

  // Studio controls.

  void toggleBrightness() => emit(state.copyWith(brightness: state.isDark ? Brightness.light : Brightness.dark));

  void setExportFormat(ExportFormat format) => emit(state.copyWith(exportFormat: format));

  void setMixerOpen(bool open) => emit(state.copyWith(mixerOpen: open));

  void toggleInspecting() => emit(state.copyWith(inspecting: !state.inspecting));

  void spotlight(Channel channel) =>
      emit(state.copyWith(spotlight: () => channel, spotlightTick: state.spotlightTick + 1));

  static List<ThemeRecipe> _push(List<ThemeRecipe> stack, ThemeRecipe recipe) {
    final next = [...stack, recipe];
    return next.length > _maxHistory ? next.sublist(next.length - _maxHistory) : next;
  }
}
