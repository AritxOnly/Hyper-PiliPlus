import 'package:PiliPlus/models/common/app_icon_style.dart';
import 'package:flutter/services.dart';

const appIconChannel = MethodChannel('hyper_piliplus/app_icon');

class AppIconState {
  const AppIconState(this.style, this.systemForeground, this.systemBackground);

  final AppIconStyle style;
  final Color systemForeground;
  final Color systemBackground;

  factory AppIconState.fromMap(Map<Object?, Object?> value) => AppIconState(
    AppIconStyle.fromId(value['style']),
    Color(value['foreground'] as int),
    Color(value['background'] as int),
  );
}

abstract final class AndroidAppIcon {
  static Future<AppIconState> current() => _invoke('get');

  static Future<AppIconState> apply(AppIconStyle style) =>
      _invoke('set', style.name);

  static Future<AppIconState> _invoke(String method, [String? style]) async {
    final value = await appIconChannel.invokeMapMethod<Object?, Object?>(
      method,
      style,
    );
    if (value == null) throw StateError('Missing launcher icon state');
    return AppIconState.fromMap(value);
  }
}
