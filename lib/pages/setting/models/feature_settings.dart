import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/models/style_settings.dart';
import 'package:material_ui/material_ui.dart';

/// Reuse the original entries, including their preference keys and callbacks.
List<SettingsModel> get featureSettings => [
  ...styleSettings.where((model) => model.featured),
  const NormalModel(
    title: '卡片展开转场',
    subtitle: '视频、动态和专栏卡片展开进入详情，支持快速返回与预测返回手势',
    leading: Icon(Icons.animation_rounded),
  ),
  const NormalModel(
    title: '紧凑播放器控件',
    subtitle: '单行排列常用控件，适配窄屏、横屏和大字体',
    leading: Icon(Icons.smart_display_outlined),
  ),
  const NormalModel(
    title: '动态详情滚动恢复',
    subtitle: '返回动态详情时恢复正文和评论的滚动位置',
    leading: Icon(Icons.restore_rounded),
  ),
  const NormalModel(
    title: 'Android 原生交互与自由窗口适配',
    subtitle: '原生文本选择操作栏、提示与 HyperOS 自由窗口边距适配，随系统自动启用',
    leading: Icon(Icons.phone_android_rounded),
  ),
];
