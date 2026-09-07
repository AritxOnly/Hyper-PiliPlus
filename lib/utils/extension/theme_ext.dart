import 'package:PiliPlus/utils/bili_colors.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:material_ui/material_ui.dart'
    show ThemeData, Color, ColorScheme, Brightness, Colors;

extension ThemeDataExt on ThemeData {
  bool get isLight => brightness.isLight;

  bool get isDark => brightness.isDark;
}

extension ColorSchemeExt on ColorScheme {
  Color get vipColor =>
      brightness.isLight ? BiliColors.pinkLight : BiliColors.pinkDark;

  Color get blue =>
      brightness.isLight ? BiliColors.blueLight : BiliColors.blueDark;

  Color get btnColor =>
      brightness.isLight ? BiliColors.pinkLight : const Color(0xFF8F0030);

  Color get freeColor =>
      brightness.isLight ? const Color(0xFFFF7F24) : const Color(0xFFD66011);

  bool get isLight => brightness.isLight;

  bool get isDark => brightness.isDark;
}

extension ColorExtension on Color {
  Color darken([double amount = .5]) {
    assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');
    return Color.lerp(this, Colors.black, amount)!;
  }

  /// Matches Deadliner's Miuix preset pipeline: Material generates every
  /// supporting role from a tonal-spot seed, while the selected preset remains
  /// the exact primary colour and always keeps white primary content.
  ColorScheme asMiuixPresetColorScheme(Brightness brightness) =>
      SeedColorScheme.fromSeeds(
        primaryKey: this,
        variant: FlexSchemeVariant.tonalSpot,
        brightness: brightness,
        useExpressiveOnContainerColors: false,
      ).copyWith(primary: this, onPrimary: Colors.white);
}

extension BrightnessExt on Brightness {
  Brightness get reverse => isLight ? Brightness.dark : Brightness.light;

  bool get isLight => this == Brightness.light;

  bool get isDark => this == Brightness.dark;
}
