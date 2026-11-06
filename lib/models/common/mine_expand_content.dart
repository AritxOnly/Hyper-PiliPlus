import 'package:PiliPlus/models/common/enum_with_label.dart';

enum MineExpandContent implements EnumWithLabel {
  favorite('收藏'),
  history('最近播放'),
  later('稍后再看'),
  ;

  @override
  final String label;

  const MineExpandContent(this.label);

  String get title => this == favorite ? '我的收藏' : label;

  String get route => switch (this) {
    favorite => '/fav',
    history => '/history',
    later => '/later',
  };
}
