import 'dart:math' as math;

/// Reserve readable space for the side panel before sizing the player.
double landscapePlayerWidth(double availableWidth, double preferredWidth) {
  final panelWidth = math.min(425.0, math.max(320.0, availableWidth * .36));
  final maxPlayerWidth = math.max(0.0, availableWidth - panelWidth);
  return preferredWidth.clamp(0.0, maxPlayerWidth);
}
