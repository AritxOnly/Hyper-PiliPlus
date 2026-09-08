import 'package:material_ui/material_ui.dart';

/// Keep the seek rail flexible instead of scaling all controls to fit.
class CompactPlayerControls extends StatelessWidget {
  const CompactPlayerControls({
    super.key,
    required this.playButton,
    required this.progress,
    required this.time,
    required this.speed,
    required this.options,
    this.fullscreenButton,
  });

  final Widget playButton;
  final Widget progress;
  final Widget time;
  final Widget speed;
  final Widget? fullscreenButton;
  final List<({String label, Widget control})> Function() options;

  void _showOptions(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xff242428),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '播放选项',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 16,
                children: options()
                    .map(
                      (option) => SizedBox(
                        width: 76,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .07),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: DefaultTextStyle.merge(
                                textAlign: TextAlign.center,
                                child: SizedBox(
                                  width: 76,
                                  height: 44,
                                  child: option.control,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              option.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 440;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .26),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            height: 48,
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                SizedBox(width: 42, height: 44, child: playButton),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: progress,
                  ),
                ),
                if (constraints.maxWidth >= 300)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: time,
                  ),
                if (wide)
                  SizedBox(
                    width: 48,
                    child: Center(child: SizedBox(height: 40, child: speed)),
                  ),
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: '播放选项',
                  onPressed: () => _showOptions(context),
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                if (fullscreenButton case final button?)
                  SizedBox(width: 40, height: 44, child: button),
              ],
            ),
          ),
        ),
      );
    },
  );
}
