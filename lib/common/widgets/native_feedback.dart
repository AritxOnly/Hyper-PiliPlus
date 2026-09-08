import 'dart:async';

import 'package:PiliPlus/common/widgets/native_navigation_occlusion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

const nativeFeedbackChannel = MethodChannel('hyper_piliplus/native_feedback');

bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Returns false only when unsupported, allowing the original Flutter UI.
Future<bool> showNativeActionMenu(
  BuildContext context,
  List<({String label, VoidCallback onSelected})> actions,
) async {
  if (!_android) return false;
  int? selected;
  try {
    selected = await nativeFeedbackChannel.invokeMethod<int>('showActions', {
      'items': actions.map((action) => action.label).toList(),
      'dark': Theme.of(context).brightness == Brightness.dark,
    });
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
  if (context.mounted &&
      selected != null &&
      selected >= 0 &&
      selected < actions.length) {
    actions[selected].onSelected();
  }
  return true;
}

/// SmartDialog still owns queue/dismiss timing; Android owns the visible Toast.
class NativeTextToast extends StatefulWidget {
  const NativeTextToast({
    super.key,
    required this.message,
    required this.fallback,
  });
  final String message;
  final WidgetBuilder fallback;

  @override
  State<NativeTextToast> createState() => _NativeTextToastState();
}

class _NativeTextToastState extends State<NativeTextToast> {
  static int _nextId = 0;
  final int _id = _nextId++;
  bool _fallback = !_android;

  @override
  void initState() {
    super.initState();
    if (!_fallback) unawaited(_show());
  }

  Future<void> _show() async {
    try {
      await nativeFeedbackChannel.invokeMethod<void>('showToast', {
        'id': _id,
        'message': widget.message,
      });
    } on PlatformException {
      if (mounted) setState(() => _fallback = true);
    } on MissingPluginException {
      if (mounted) setState(() => _fallback = true);
    }
  }

  Future<void> _cancel() async {
    try {
      await nativeFeedbackChannel.invokeMethod<void>('cancelToast', {
        'id': _id,
      });
    } on PlatformException {
      // Activity/engine may already have been destroyed.
    } on MissingPluginException {
      // Non-Android hosts use the Flutter fallback.
    }
  }

  @override
  void dispose() {
    if (_android) unawaited(_cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _fallback
      ? NativeNavigationForeground(child: widget.fallback(context))
      : const SizedBox.shrink();
}
