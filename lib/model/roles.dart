import 'package:material_ui/material_ui.dart';

import 'recipe.dart';

enum RoleGroup(final String label) {
  accents('Accents'),
  fixed('Fixed accents'),
  surfaces('Surfaces'),
  lines('Lines & inverse'),
}

/// Every color role in a Material 3 [ColorScheme].
enum Role(final String label, final Channel channel, final RoleGroup group, final Color Function(ColorScheme) of) {
  primary('primary', Channel.primary, RoleGroup.accents, _primary),
  onPrimary('onPrimary', Channel.primary, RoleGroup.accents, _onPrimary),
  primaryContainer('primaryContainer', Channel.primary, RoleGroup.accents, _primaryContainer),
  onPrimaryContainer('onPrimaryContainer', Channel.primary, RoleGroup.accents, _onPrimaryContainer),
  secondary('secondary', Channel.secondary, RoleGroup.accents, _secondary),
  onSecondary('onSecondary', Channel.secondary, RoleGroup.accents, _onSecondary),
  secondaryContainer('secondaryContainer', Channel.secondary, RoleGroup.accents, _secondaryContainer),
  onSecondaryContainer('onSecondaryContainer', Channel.secondary, RoleGroup.accents, _onSecondaryContainer),
  tertiary('tertiary', Channel.tertiary, RoleGroup.accents, _tertiary),
  onTertiary('onTertiary', Channel.tertiary, RoleGroup.accents, _onTertiary),
  tertiaryContainer('tertiaryContainer', Channel.tertiary, RoleGroup.accents, _tertiaryContainer),
  onTertiaryContainer('onTertiaryContainer', Channel.tertiary, RoleGroup.accents, _onTertiaryContainer),
  error('error', Channel.error, RoleGroup.accents, _error),
  onError('onError', Channel.error, RoleGroup.accents, _onError),
  errorContainer('errorContainer', Channel.error, RoleGroup.accents, _errorContainer),
  onErrorContainer('onErrorContainer', Channel.error, RoleGroup.accents, _onErrorContainer),

  primaryFixed('primaryFixed', Channel.primary, RoleGroup.fixed, _primaryFixed),
  primaryFixedDim('primaryFixedDim', Channel.primary, RoleGroup.fixed, _primaryFixedDim),
  onPrimaryFixed('onPrimaryFixed', Channel.primary, RoleGroup.fixed, _onPrimaryFixed),
  onPrimaryFixedVariant('onPrimaryFixedVariant', Channel.primary, RoleGroup.fixed, _onPrimaryFixedVariant),
  secondaryFixed('secondaryFixed', Channel.secondary, RoleGroup.fixed, _secondaryFixed),
  secondaryFixedDim('secondaryFixedDim', Channel.secondary, RoleGroup.fixed, _secondaryFixedDim),
  onSecondaryFixed('onSecondaryFixed', Channel.secondary, RoleGroup.fixed, _onSecondaryFixed),
  onSecondaryFixedVariant('onSecondaryFixedVariant', Channel.secondary, RoleGroup.fixed, _onSecondaryFixedVariant),
  tertiaryFixed('tertiaryFixed', Channel.tertiary, RoleGroup.fixed, _tertiaryFixed),
  tertiaryFixedDim('tertiaryFixedDim', Channel.tertiary, RoleGroup.fixed, _tertiaryFixedDim),
  onTertiaryFixed('onTertiaryFixed', Channel.tertiary, RoleGroup.fixed, _onTertiaryFixed),
  onTertiaryFixedVariant('onTertiaryFixedVariant', Channel.tertiary, RoleGroup.fixed, _onTertiaryFixedVariant),

  surfaceDim('surfaceDim', Channel.neutral, RoleGroup.surfaces, _surfaceDim),
  surface('surface', Channel.neutral, RoleGroup.surfaces, _surface),
  surfaceBright('surfaceBright', Channel.neutral, RoleGroup.surfaces, _surfaceBright),
  surfaceContainerLowest('surfaceContainerLowest', Channel.neutral, RoleGroup.surfaces, _scLowest),
  surfaceContainerLow('surfaceContainerLow', Channel.neutral, RoleGroup.surfaces, _scLow),
  surfaceContainer('surfaceContainer', Channel.neutral, RoleGroup.surfaces, _sc),
  surfaceContainerHigh('surfaceContainerHigh', Channel.neutral, RoleGroup.surfaces, _scHigh),
  surfaceContainerHighest('surfaceContainerHighest', Channel.neutral, RoleGroup.surfaces, _scHighest),
  onSurface('onSurface', Channel.neutral, RoleGroup.surfaces, _onSurface),
  onSurfaceVariant('onSurfaceVariant', Channel.neutralVariant, RoleGroup.surfaces, _onSurfaceVariant),

  outline('outline', Channel.neutralVariant, RoleGroup.lines, _outline),
  outlineVariant('outlineVariant', Channel.neutralVariant, RoleGroup.lines, _outlineVariant),
  inverseSurface('inverseSurface', Channel.neutral, RoleGroup.lines, _inverseSurface),
  onInverseSurface('onInverseSurface', Channel.neutral, RoleGroup.lines, _onInverseSurface),
  inversePrimary('inversePrimary', Channel.primary, RoleGroup.lines, _inversePrimary),
  scrim('scrim', Channel.neutral, RoleGroup.lines, _scrim),
  shadow('shadow', Channel.neutral, RoleGroup.lines, _shadow);

  String get kebab => label.replaceAllMapped(RegExp('[A-Z]'), (m) => '-${m[0]!.toLowerCase()}');

  /// The role this one is usually drawn on, or drawn with.
  Role? get partner => switch (this) {
    primary => onPrimary,
    onPrimary => primary,
    primaryContainer => onPrimaryContainer,
    onPrimaryContainer => primaryContainer,
    secondary => onSecondary,
    onSecondary => secondary,
    secondaryContainer => onSecondaryContainer,
    onSecondaryContainer => secondaryContainer,
    tertiary => onTertiary,
    onTertiary => tertiary,
    tertiaryContainer => onTertiaryContainer,
    onTertiaryContainer => tertiaryContainer,
    error => onError,
    onError => error,
    errorContainer => onErrorContainer,
    onErrorContainer => errorContainer,
    primaryFixed || primaryFixedDim => onPrimaryFixed,
    onPrimaryFixed || onPrimaryFixedVariant => primaryFixed,
    secondaryFixed || secondaryFixedDim => onSecondaryFixed,
    onSecondaryFixed || onSecondaryFixedVariant => secondaryFixed,
    tertiaryFixed || tertiaryFixedDim => onTertiaryFixed,
    onTertiaryFixed || onTertiaryFixedVariant => tertiaryFixed,
    onSurface || onSurfaceVariant => surface,
    inverseSurface => onInverseSurface,
    onInverseSurface => inverseSurface,
    inversePrimary => inverseSurface,
    outline || outlineVariant => surface,
    scrim || shadow => null,
    _ => onSurface,
  };
}

Color _primary(ColorScheme c) => c.primary;
Color _onPrimary(ColorScheme c) => c.onPrimary;
Color _primaryContainer(ColorScheme c) => c.primaryContainer;
Color _onPrimaryContainer(ColorScheme c) => c.onPrimaryContainer;
Color _secondary(ColorScheme c) => c.secondary;
Color _onSecondary(ColorScheme c) => c.onSecondary;
Color _secondaryContainer(ColorScheme c) => c.secondaryContainer;
Color _onSecondaryContainer(ColorScheme c) => c.onSecondaryContainer;
Color _tertiary(ColorScheme c) => c.tertiary;
Color _onTertiary(ColorScheme c) => c.onTertiary;
Color _tertiaryContainer(ColorScheme c) => c.tertiaryContainer;
Color _onTertiaryContainer(ColorScheme c) => c.onTertiaryContainer;
Color _error(ColorScheme c) => c.error;
Color _onError(ColorScheme c) => c.onError;
Color _errorContainer(ColorScheme c) => c.errorContainer;
Color _onErrorContainer(ColorScheme c) => c.onErrorContainer;
Color _primaryFixed(ColorScheme c) => c.primaryFixed;
Color _primaryFixedDim(ColorScheme c) => c.primaryFixedDim;
Color _onPrimaryFixed(ColorScheme c) => c.onPrimaryFixed;
Color _onPrimaryFixedVariant(ColorScheme c) => c.onPrimaryFixedVariant;
Color _secondaryFixed(ColorScheme c) => c.secondaryFixed;
Color _secondaryFixedDim(ColorScheme c) => c.secondaryFixedDim;
Color _onSecondaryFixed(ColorScheme c) => c.onSecondaryFixed;
Color _onSecondaryFixedVariant(ColorScheme c) => c.onSecondaryFixedVariant;
Color _tertiaryFixed(ColorScheme c) => c.tertiaryFixed;
Color _tertiaryFixedDim(ColorScheme c) => c.tertiaryFixedDim;
Color _onTertiaryFixed(ColorScheme c) => c.onTertiaryFixed;
Color _onTertiaryFixedVariant(ColorScheme c) => c.onTertiaryFixedVariant;
Color _surfaceDim(ColorScheme c) => c.surfaceDim;
Color _surface(ColorScheme c) => c.surface;
Color _surfaceBright(ColorScheme c) => c.surfaceBright;
Color _scLowest(ColorScheme c) => c.surfaceContainerLowest;
Color _scLow(ColorScheme c) => c.surfaceContainerLow;
Color _sc(ColorScheme c) => c.surfaceContainer;
Color _scHigh(ColorScheme c) => c.surfaceContainerHigh;
Color _scHighest(ColorScheme c) => c.surfaceContainerHighest;
Color _onSurface(ColorScheme c) => c.onSurface;
Color _onSurfaceVariant(ColorScheme c) => c.onSurfaceVariant;
Color _outline(ColorScheme c) => c.outline;
Color _outlineVariant(ColorScheme c) => c.outlineVariant;
Color _inverseSurface(ColorScheme c) => c.inverseSurface;
Color _onInverseSurface(ColorScheme c) => c.onInverseSurface;
Color _inversePrimary(ColorScheme c) => c.inversePrimary;
Color _scrim(ColorScheme c) => c.scrim;
Color _shadow(ColorScheme c) => c.shadow;
