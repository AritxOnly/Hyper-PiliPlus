import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

const nativeSelectionChannel = MethodChannel('hyper_piliplus/text_selection');

/// Flutter keeps the selection and action callbacks; Android paints only the
/// floating ActionMode toolbar. No native dialog or duplicate text field.
class NativeSelectionToolbar extends StatefulWidget {
  const NativeSelectionToolbar({
    super.key,
    required this.buttonItems,
    required this.anchors,
    required this.onDismiss,
  });
  final List<ContextMenuButtonItem> buttonItems;
  final TextSelectionToolbarAnchors anchors;
  final VoidCallback onDismiss;

  @override
  State<NativeSelectionToolbar> createState() => _NativeSelectionToolbarState();
}

class _NativeSelectionToolbarState extends State<NativeSelectionToolbar> {
  static int _nextId = 0;
  final _id = _nextId++;
  bool _started = false;
  bool _scheduled = false;
  bool _fallback = kIsWeb || defaultTargetPlatform != TargetPlatform.android;

  void _schedule() {
    if (_scheduled || _fallback) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted && !_fallback) unawaited(_sync());
    });
  }

  Future<void> _sync() async {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final primary = widget.anchors.primaryAnchor;
    final secondary = widget.anchors.secondaryAnchor ?? primary;
    final arguments = {
      'id': _id,
      'x': primary.dx * ratio,
      'y': primary.dy * ratio,
      'endX': secondary.dx * ratio,
      'endY': secondary.dy * ratio,
      'items': widget.buttonItems
          .map(
            (item) => {
              'label': AdaptiveTextSelectionToolbar.getButtonLabel(
                context,
                item,
              ),
              'enabled': item.onPressed != null,
            },
          )
          .toList(),
    };
    try {
      if (_started) {
        await nativeSelectionChannel.invokeMethod<void>('update', arguments);
        return;
      }
      _started = true;
      final selected = await nativeSelectionChannel.invokeMethod<int>(
        'show',
        arguments,
      );
      if (!mounted) return;
      _started = false;
      if (selected != null &&
          selected >= 0 &&
          selected < widget.buttonItems.length) {
        widget.buttonItems[selected].onPressed?.call();
        // Select-all can keep the Flutter selection toolbar mounted.
        if (mounted) setState(() {});
      } else {
        widget.onDismiss();
      }
    } on PlatformException {
      if (mounted) setState(() => _fallback = true);
    } on MissingPluginException {
      if (mounted) setState(() => _fallback = true);
    }
  }

  Future<void> _hide() async {
    try {
      await nativeSelectionChannel.invokeMethod<void>('hide', {'id': _id});
    } on PlatformException {
      // Activity may already be gone.
    } on MissingPluginException {
      // Unsupported hosts keep the Flutter toolbar.
    }
  }

  @override
  void dispose() {
    if (_started) unawaited(_hide());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _schedule();
    return _fallback
        ? AdaptiveTextSelectionToolbar.buttonItems(
            buttonItems: widget.buttonItems,
            anchors: widget.anchors,
          )
        : const SizedBox.shrink();
  }
}
