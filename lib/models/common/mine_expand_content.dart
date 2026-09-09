import 'package:PiliPlus/models/common/enum_with_label.dart';

enum MineExpandContent implements EnumWithLabel {
  favorite('收藏'),
  history('最近播放'),
  ;

  @override
  final String label;

  const MineExpandContent(this.label);
}
