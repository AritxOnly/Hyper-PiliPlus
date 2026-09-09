import 'package:flutter/widgets.dart';

/// Records the source list before opening a reply route. NestedScrollView needs
/// one combined offset: jumping its inner/outer positions separately resets the
/// other position through the shared coordinator.
class ScrollPositionBookmark {
  ScrollPositionBookmark._(this._restore);

  final VoidCallback _restore;

  factory ScrollPositionBookmark.capture(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return ScrollPositionBookmark._(() {});
    final position = scrollable.position;
    final nested = context.findAncestorStateOfType<NestedScrollViewState>();
    if (nested != null &&
        nested.innerController.positions.contains(position) &&
        nested.outerController.hasClients) {
      final outer = nested.outerController.position;
      final offset = outer.pixels + position.pixels;
      return ScrollPositionBookmark._(() {
        if (!nested.mounted ||
            !scrollable.mounted ||
            !nested.outerController.hasClients ||
            !nested.innerController.positions.contains(scrollable.position)) {
          return;
        }
        final outer = nested.outerController.position;
        final position = scrollable.position;
        if ((outer.pixels + position.pixels - offset).abs() < .5) return;
        nested.outerController.jumpTo(
          offset.clamp(
            outer.minScrollExtent,
            outer.maxScrollExtent + position.maxScrollExtent,
          ),
        );
      });
    }
    final offset = position.pixels;
    return ScrollPositionBookmark._(() {
      if (!scrollable.mounted) return;
      final position = scrollable.position;
      if ((position.pixels - offset).abs() < .5) return;
      position.jumpTo(
        offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  void restore() {
    // Wait for the uncovered route to lay out before clamping the saved offset.
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
