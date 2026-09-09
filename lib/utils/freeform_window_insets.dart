import 'package:flutter/widgets.dart';

/// Guards against malformed freeform insets reported by some HyperOS builds.
///
/// In mini freeform mode HyperOS can report the entire task height as the top
/// system inset. A safe area using that value gives its child no remaining
/// height, even though the Flutter surface itself is valid.
abstract final class FreeformWindowInsets {
  static EdgeInsets normalize({
    required EdgeInsets insets,
    required Size viewSize,
  }) {
    if (viewSize.isEmpty) return insets;

    // A status/navigation inset cannot validly take this much of the logical
    // window. Keep the unaffected edge so real gesture insets still apply.
    final abnormalThreshold = viewSize.height * 0.4;
    final topAbnormal = insets.top > abnormalThreshold;
    final bottomAbnormal = insets.bottom > abnormalThreshold;
    if (!topAbnormal && !bottomAbnormal) return insets;
    return insets.copyWith(
      top: topAbnormal ? 0 : insets.top,
      bottom: bottomAbnormal ? 0 : insets.bottom,
    );
  }
}
