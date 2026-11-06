import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/slotted_layout_helper.dart';
import 'package:flutter/rendering.dart' show ChildLayoutHelper;
import 'package:material_ui/material_ui.dart';

class SimpleScaffold extends StatelessWidget {
  const SimpleScaffold({
    super.key,
    this.backgroundColor,
    this.fab,
    this.appBar,
    this.extendBodyBehindAppBar = false,
    required this.body,
  });

  final Color? backgroundColor;
  final Widget? fab;
  final Widget? appBar;
  final Widget body;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: ScaffoldLayout(
        fab: fab,
        appBar: appBar,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        body: body,
      ),
    );
  }
}

enum ScaffoldType { fab, appBar, body }

class ScaffoldLayout
    extends SlottedMultiChildRenderObjectWidget<ScaffoldType, RenderBox> {
  const ScaffoldLayout({
    super.key,
    this.fab,
    this.appBar,
    this.extendBodyBehindAppBar = false,
    required this.body,
  });

  final Widget? fab;
  final Widget? appBar;
  final Widget body;
  final bool extendBodyBehindAppBar;

  @override
  Iterable<ScaffoldType> get slots => ScaffoldType.values;

  @override
  Widget? childForSlot(slot) => switch (slot) {
    .fab => fab,
    .appBar => appBar,
    .body => body,
  };

  @override
  SlottedContainerRenderObjectMixin<ScaffoldType, RenderBox> createRenderObject(
    BuildContext context,
  ) {
    return _RenderScaffoldLayout(extendBodyBehindAppBar);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant SlottedContainerRenderObjectMixin<ScaffoldType, RenderBox>
    renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _RenderScaffoldLayout).extendBodyBehindAppBar =
        extendBodyBehindAppBar;
  }
}

class _RenderScaffoldLayout extends RenderBox
    with
        SlottedContainerRenderObjectMixin<ScaffoldType, RenderBox>,
        SlottedLayoutMixin {
  _RenderScaffoldLayout(this._extendBodyBehindAppBar);

  bool _extendBodyBehindAppBar;
  set extendBodyBehindAppBar(bool value) {
    if (_extendBodyBehindAppBar == value) return;
    _extendBodyBehindAppBar = value;
    markNeedsLayout();
  }

  RenderBox? get fab => childForSlot(.fab);
  RenderBox? get appBar => childForSlot(.appBar);
  RenderBox get body => childForSlot(.body)!;

  @override
  Iterable<ScaffoldType> get slots => ScaffoldType.values;

  @override
  void performLayout() {
    final constraints = this.constraints;
    size = constraints.biggest;

    final Offset bodyOffset;
    final BoxConstraints bodyConstraints;

    final appBar = this.appBar;
    if (appBar != null) {
      final appBarHeight = ChildLayoutHelper.layoutChild(
        appBar,
        BoxConstraints.tightFor(width: constraints.maxWidth),
      ).height;
      setOffset(appBar, .zero);

      bodyOffset = Offset(0, _extendBodyBehindAppBar ? 0 : appBarHeight);
      bodyConstraints = BoxConstraints.tightFor(
        width: constraints.maxWidth,
        height: math.max(constraints.maxHeight - bodyOffset.dy, 0.0),
      );
    } else {
      bodyOffset = .zero;
      bodyConstraints = constraints;
    }

    final body = this.body..layout(bodyConstraints);
    setOffset(body, bodyOffset);

    final fab = this.fab;
    if (fab != null) {
      final fabSize = ChildLayoutHelper.layoutChild(fab, constraints.loosen());
      setOffset(
        fab,
        Offset(
          constraints.maxWidth - fabSize.width,
          constraints.maxHeight - fabSize.height,
        ),
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    void doPaint(RenderBox? child) {
      if (child != null) {
        context.paintChild(child, getOffset(child) + offset);
      }
    }

    doPaint(body);
    doPaint(appBar);
    doPaint(fab);
  }
}
