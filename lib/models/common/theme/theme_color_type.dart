import 'package:material_ui/material_ui.dart';

const List<({Color lightColor, Color darkColor, String label})>
colorThemeTypes = [
  // Keep the default preset in sync with Deadliner's Miuix preset.
  (
    lightColor: Color(0xFF3382FF),
    darkColor: Color(0xFF277AF7),
    label: '澎湃蓝',
  ),
  (
    lightColor: Color(0xFFFF7299),
    darkColor: Color(0xFFFF7299),
    label: '粉红色',
  ),
  (lightColor: Colors.red, darkColor: Colors.red, label: '红色'),
  (lightColor: Colors.orange, darkColor: Colors.orange, label: '橙色'),
  (lightColor: Colors.amber, darkColor: Colors.amber, label: '琥珀色'),
  (lightColor: Colors.yellow, darkColor: Colors.yellow, label: '黄色'),
  (lightColor: Colors.lime, darkColor: Colors.lime, label: '酸橙色'),
  (lightColor: Colors.lightGreen, darkColor: Colors.lightGreen, label: '浅绿色'),
  (lightColor: Colors.green, darkColor: Colors.green, label: '绿色'),
  (lightColor: Colors.teal, darkColor: Colors.teal, label: '青色'),
  (lightColor: Colors.cyan, darkColor: Colors.cyan, label: '蓝绿色'),
  (lightColor: Colors.lightBlue, darkColor: Colors.lightBlue, label: '浅蓝色'),
  (lightColor: Colors.blue, darkColor: Colors.blue, label: '蓝色'),
  (lightColor: Colors.indigo, darkColor: Colors.indigo, label: '靛蓝色'),
  (lightColor: Colors.purple, darkColor: Colors.purple, label: '紫色'),
  (lightColor: Colors.deepPurple, darkColor: Colors.deepPurple, label: '深紫色'),
  (lightColor: Colors.blueGrey, darkColor: Colors.blueGrey, label: '蓝灰色'),
  (lightColor: Colors.brown, darkColor: Colors.brown, label: '棕色'),
  (lightColor: Colors.grey, darkColor: Colors.grey, label: '灰色'),
];

extension ThemeColorTypeExt
    on ({Color lightColor, Color darkColor, String label}) {
  Color colorFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkColor : lightColor;
}
