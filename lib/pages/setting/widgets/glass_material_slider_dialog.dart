import 'package:PiliPlus/models/common/glass_material_tuning.dart';
import 'package:material_ui/material_ui.dart';

/// Flutter settings host for Deadliner's single blur-size slider (16–168, default 84).
class GlassMaterialSliderDialog extends StatefulWidget {
  const GlassMaterialSliderDialog({super.key, required this.value});
  final double value;

  @override
  State<GlassMaterialSliderDialog> createState() =>
      _GlassMaterialSliderDialogState();
}

class _GlassMaterialSliderDialogState extends State<GlassMaterialSliderDialog> {
  late double _value = GlassMaterialTuning.normalize(widget.value);

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    const fraction =
        (GlassMaterialTuning.defaultBlurRadius -
            GlassMaterialTuning.minBlurRadius) /
        (GlassMaterialTuning.maxBlurRadius - GlassMaterialTuning.minBlurRadius);
    return AlertDialog(
      title: const Text('柔光玻璃通透程度'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            Text('模糊大小 ${_value.round()}', textAlign: .center),
            Slider(
              value: _value,
              min: GlassMaterialTuning.minBlurRadius,
              max: GlassMaterialTuning.maxBlurRadius,
              padding: const .symmetric(horizontal: 20),
              label: '${_value.round()}',
              semanticFormatterCallback: (value) => '模糊大小 ${value.round()}',
              onChanged: (value) =>
                  setState(() => _value = value.roundToDouble()),
            ),
            // Keep the default visible even when the thumb covers the track point.
            Padding(
              padding: const .symmetric(horizontal: 20),
              child: Align(
                alignment: const AlignmentDirectional(fraction * 2 - 1, 0),
                child: SizedBox(
                  width: 2,
                  height: 7,
                  child: ColoredBox(color: colors.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              alignment: .spaceBetween,
              spacing: 8,
              children: [Text('更通透'), Text('默认 84'), Text('更柔和')],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              setState(() => _value = GlassMaterialTuning.defaultBlurRadius),
          child: const Text('恢复默认'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_value),
          child: const Text('应用'),
        ),
      ],
    );
  }
}
