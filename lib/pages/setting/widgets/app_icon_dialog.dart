import 'package:PiliPlus/models/common/app_icon_style.dart';
import 'package:PiliPlus/utils/android/app_icon.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

class AppIconDialog extends StatefulWidget {
  const AppIconDialog({super.key});

  @override
  State<AppIconDialog> createState() => _AppIconDialogState();
}

class _AppIconDialogState extends State<AppIconDialog> {
  AppIconState? _current;
  AppIconStyle _selected = .system;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = await AndroidAppIcon.current();
      if (!mounted) return;
      setState(() {
        _current = state;
        _selected = state.style;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法读取图标设置，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apply() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final state = await AndroidAppIcon.apply(_selected);
      if (state.style != _selected) throw StateError('Icon was not applied');
      await GStorage.setting.put(SettingBoxKey.appIconStyle, state.style.name);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _error = '图标切换失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('应用图标'),
        constraints: const BoxConstraints(maxWidth: 440),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                const Text('选择前景与背景配色，固定配色不随深浅模式变化。'),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_current case final current?)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 330 ? 3 : 2;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 10) / columns;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final style in AppIconStyle.values)
                            SizedBox(
                              width: width,
                              child: Semantics(
                                button: true,
                                enabled: !_saving,
                                selected: style == _selected,
                                label: '${style.label}图标',
                                onTap: _saving
                                    ? null
                                    : () => setState(
                                        () => _selected = style,
                                      ),
                                child: ExcludeSemantics(
                                  child: Material(
                                    color: style == _selected
                                        ? colors.primaryContainer
                                        : colors.surfaceContainerLow,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: .circular(16),
                                      side: BorderSide(
                                        color: style == _selected
                                            ? colors.primary
                                            : colors.outlineVariant,
                                      ),
                                    ),
                                    clipBehavior: .antiAlias,
                                    child: InkWell(
                                      onTap: _saving
                                          ? null
                                          : () => setState(
                                              () => _selected = style,
                                            ),
                                      child: Padding(
                                        padding: const .all(12),
                                        child: Column(
                                          mainAxisSize: .min,
                                          children: [
                                            AppIconPreview(
                                              style: style,
                                              systemForeground:
                                                  current.systemForeground,
                                              systemBackground:
                                                  current.systemBackground,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              style.label,
                                              textAlign: .center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                if (_error case final error?) ...[
                  const SizedBox(height: 12),
                  Text(error, style: TextStyle(color: colors.error)),
                  if (_current == null && !_loading)
                    TextButton(onPressed: _load, child: const Text('重试')),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving || _loading || _current == null
                ? null
                : () => setState(() => _selected = .system),
            child: const Text('恢复默认'),
          ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed:
                _saving ||
                    _loading ||
                    _current == null ||
                    _selected == _current?.style
                ? null
                : _apply,
            child: Text(_saving ? '正在应用' : '应用'),
          ),
        ],
      ),
    );
  }
}

/// Same P outline and 108dp viewport as Android's adaptive launcher foreground.
class AppIconPreview extends StatelessWidget {
  const AppIconPreview({
    super.key,
    required this.style,
    required this.systemForeground,
    required this.systemBackground,
  });

  final AppIconStyle style;
  final Color systemForeground;
  final Color systemBackground;

  @override
  Widget build(BuildContext context) {
    final foreground = style.foreground ?? systemForeground;
    final background = style.background ?? systemBackground;
    final hex = (foreground.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    return ClipRRect(
      borderRadius: .circular(16),
      child: ColoredBox(
        color: background,
        child: SvgPicture.string(
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">'
          '<path fill="#$hex" fill-rule="evenodd" d="M56,54L39.78,54l2.22,-10.94h14c3.02,0 5.47,2.45 5.47,5.47 0,3.02 -2.45,5.47 -5.47,5.47zM56,35.77h-9.62l-7.13,36.45h7.51L48.92,61.29h7.08c7.05,0 12.76,-5.71 12.76,-12.76 0,-7.05 -5.71,-12.76 -12.76,-12.76z"/>'
          '</svg>',
          width: 64,
          height: 64,
        ),
      ),
    );
  }
}
