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

  /// Lays the mixer out as horizontal rows instead of a desk of vertical strips.
  final bool mixerRows = false,

  /// The channel the inspector last pointed at, to light up on the desk.
  final Channel? spotlight,
  final int spotlightTick = 0,
  /// True while the user is actively dragging a continuous control.
  final bool scrubbing = false,
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
    bool? mixerRows,
    Channel? Function()? spotlight,
    int? spotlightTick,
    bool? scrubbing,
    List<ThemeRecipe>? undoStack,
    List<ThemeRecipe>? redoStack,
  }) => StudioState(
    recipe: recipe ?? this.recipe,
    brightness: brightness ?? this.brightness,
    exportFormat: exportFormat ?? this.exportFormat,
    inspecting: inspecting ?? this.inspecting,
    mixerOpen: mixerOpen ?? this.mixerOpen,
    mixerRows: mixerRows ?? this.mixerRows,
    spotlight: spotlight != null ? spotlight() : this.spotlight,
    spotlightTick: spotlightTick ?? this.spotlightTick,
    scrubbing: scrubbing ?? this.scrubbing,
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
    mixerRows,
    spotlight,
    spotlightTick,
    scrubbing,
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
          restored = StudioState(
            recipe: recipe,
            brightness: json['dark'] == true ? Brightness.dark : Brightness.light,
            mixerRows: json['rows'] == true,
          );
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
    if (_scrubStart == null &&
        (prev.recipe != next.recipe || prev.brightness != next.brightness || prev.mixerRows != next.mixerRows)) {
      _save(next);
    }
  }

  void _save(StudioState s) => unawaited(
    _prefs?.setString(_storageKey, jsonEncode({'recipe': s.recipe.toJson(), 'dark': s.isDark, 'rows': s.mixerRows})),
  );

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
  void beginScrub() {
    _scrubStart ??= state.recipe;
    if (!state.scrubbing) emit(state.copyWith(scrubbing: true));
  }

  void endScrub() {
    final start = _scrubStart;
    _scrubStart = null;
    if (start == null || start == state.recipe) {
      if (state.scrubbing) emit(state.copyWith(scrubbing: false));
      return;
    }
    emit(state.copyWith(scrubbing: false, undoStack: _push(state.undoStack, start), redoStack: const []));
    _save(state);
  }

  void setSeed(Color seed, {bool live = false}) => _commit(
    state.recipe.copyWith(seed: seed, name: () => null),
    live: live,
  );

  void setVariant(Variant variant, {bool live = false}) => _commit(state.recipe.copyWith(variant: variant), live: live);

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

  /// Sets the chroma a channel shows now, at the current Vivid or Surface tint.
  void setChannelChroma(Channel channel, double? chroma, {bool live = false}) {
    final mix = state.recipe.mixOf(channel);
    final next = chroma == null ? mix.withChroma(null) : mix.withChroma(_unscaled(channel, chroma)).withMuted(false);
    _commit(state.recipe.withMix(channel, next), live: live);
  }

  /// Sets a channel's hue and the chroma it shows now. The scheme picks each
  /// role's tone.
  void plugChannel(Channel channel, {required double hue, required double chroma}) =>
      _commit(state.recipe.withMix(channel, ChannelMix(hue: hue % 360, chroma: _unscaled(channel, chroma))));

  /// At a scale of 0 every chroma shows as gray, so store it as given.
  double _unscaled(Channel channel, double chroma) {
    final scale = state.recipe.scaleOf(channel);
    return chroma.clamp(0.0, channel.maxChroma) / (scale > 0 ? scale : 1);
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

  void setMixerRows(bool rows) => emit(state.copyWith(mixerRows: rows));

  void toggleInspecting() => emit(state.copyWith(inspecting: !state.inspecting));

  void spotlight(Channel channel) =>
      emit(state.copyWith(spotlight: () => channel, spotlightTick: state.spotlightTick + 1));

  static List<ThemeRecipe> _push(List<ThemeRecipe> stack, ThemeRecipe recipe) {
    final next = [...stack, recipe];
    return next.length > _maxHistory ? next.sublist(next.length - _maxHistory) : next;
  }
}
