import 'package:PiliPlus/models/common/theme/theme_color_type.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart' as miuix;

/// Project-wide entry point for HyperOS-style switches.
///
/// The app's selected preset remains the source of the checked primary color,
/// even beneath a locally overridden Material theme.
class PiliMiuixSwitch extends StatelessWidget {
  const PiliMiuixSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = colorThemeTypes[Pref.customColor].colorFor(
      scheme.brightness,
    );
    final disabledTrack = scheme.onSurface.withValues(alpha: 0.12);
    final disabledThumb = scheme.onSurface.withValues(alpha: 0.38);

    return miuix.MiuixSwitch(
      value: value,
      onChanged: onChanged,
      enabled: enabled,
      colors: miuix.MiuixSwitchColors(
        checkedThumbColor: Colors.white,
        uncheckedThumbColor: scheme.onSecondary,
        disabledCheckedThumbColor: disabledThumb,
        disabledUncheckedThumbColor: disabledThumb,
        checkedTrackColor: primary,
        uncheckedTrackColor: scheme.secondary,
        disabledCheckedTrackColor: disabledTrack,
        disabledUncheckedTrackColor: disabledTrack,
      ),
    );
  }
}
