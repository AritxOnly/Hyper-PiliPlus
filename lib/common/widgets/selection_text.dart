import 'package:material_ui/material_ui.dart';
import 'package:PiliPlus/common/widgets/native_selection_toolbar.dart';

class SelectionText extends StatelessWidget {
  const SelectionText(
    String this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.contextMenuBuilder = _defaultContextMenuBuilder,
  }) : textSpan = null;

  const SelectionText.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.textAlign,
    this.contextMenuBuilder = _defaultContextMenuBuilder,
  }) : data = null;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final TextAlign? textAlign;
  final SelectableRegionContextMenuBuilder? contextMenuBuilder;

  static Widget _defaultContextMenuBuilder(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    return NativeSelectionToolbar(
      buttonItems: selectableRegionState.contextMenuButtonItems,
      anchors: selectableRegionState.contextMenuAnchors,
      onDismiss: selectableRegionState.hideToolbar,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      contextMenuBuilder: contextMenuBuilder,
      child: Text.rich(
        style: style,
        textAlign: textAlign,
        TextSpan(
          text: data,
          children: textSpan != null ? <InlineSpan>[textSpan!] : null,
        ),
      ),
    );
  }
}
