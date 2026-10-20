import 'package:flutter/painting.dart';

/// Stable IDs shared with Android's launcher aliases. Keep these across updates.
enum AppIconStyle {
  system('跟随系统', null, null),
  mint('青竹', 0xFF237A4B, 0xFFE2F3E8),
  ocean('晴蓝', 0xFF2056A6, 0xFFE6EFFF),
  rose('樱粉', 0xFFA83263, 0xFFFFE6EE),
  violet('鸢紫', 0xFF6844AE, 0xFFF0E7FF),
  sunset('暖杏', 0xFF88490C, 0xFFFFF0D8),
  graphite('石墨', 0xFFF4F4F5, 0xFF25262B);

  const AppIconStyle(this.label, this.foregroundArgb, this.backgroundArgb);

  final String label;
  final int? foregroundArgb;
  final int? backgroundArgb;

  Color? get foreground =>
      foregroundArgb == null ? null : Color(foregroundArgb!);
  Color? get background =>
      backgroundArgb == null ? null : Color(backgroundArgb!);

  static AppIconStyle fromId(Object? id) => values.firstWhere(
    (style) => style.name == id,
    orElse: () => system,
  );
}
