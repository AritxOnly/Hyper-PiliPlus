/// Deadliner AdvancedMaterialTuning: blur size, not an extra opacity overlay.
abstract final class GlassMaterialTuning {
  static const double minBlurRadius = 16;
  static const double defaultBlurRadius = 84;
  static const double maxBlurRadius = 168;

  static double normalize(Object? value) => value is num && value.isFinite
      ? value.toDouble().clamp(minBlurRadius, maxBlurRadius)
      : defaultBlurRadius;
}
