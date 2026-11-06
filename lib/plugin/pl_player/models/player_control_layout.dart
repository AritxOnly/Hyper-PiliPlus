import 'package:PiliPlus/models/common/enum_with_label.dart';

enum PlayerControlLayout implements EnumWithLabel {
  compact('紧凑单行'),
  upstream('上游双行');

  const PlayerControlLayout(this.label);

  @override
  final String label;

  static PlayerControlLayout fromPreference(Object? value) => values.firstWhere(
    (layout) => layout.name == value,
    orElse: () => compact,
  );
}
