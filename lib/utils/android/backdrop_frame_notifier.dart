import 'dart:async';
import 'dart:ui' show FrameTiming;

import 'package:flutter/widgets.dart';

/// Wakes native glass after asynchronous Flutter paints (refreshes, images,
/// programmatic scrolling). Native touch sampling still handles fast scrolling.
/// A trailing notification preserves the last frame without idle polling.
class BackdropFrameNotifier with WidgetsBindingObserver {
  BackdropFrameNotifier({required this.onFrameReady}) {
    _resumed =
        _binding.lifecycleState == null ||
        _binding.lifecycleState == AppLifecycleState.resumed;
    _binding.addObserver(this);
  }

  final Future<void> Function() onFrameReady;
  final WidgetsBinding _binding = WidgetsBinding.instance;
  static const interval = Duration(milliseconds: 80);
  bool _visible = false;
  bool _paused = false;
  bool _occluded = false;
  bool _resumed = true;
  bool _listening = false;
  bool _disposed = false;
  bool _dirty = false;
  Timer? _cooldown;

  void configure({bool? visible, bool? paused, bool? occluded}) {
    if (_disposed) return;
    _visible = visible ?? _visible;
    _paused = paused ?? _paused;
    _occluded = occluded ?? _occluded;
    _syncListening();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncListening();
  }

  void _syncListening() {
    final listen = !_disposed && _visible && !_paused && !_occluded && _resumed;
    if (listen == _listening) return;
    _listening = listen;
    if (listen) {
      _binding.addTimingsCallback(onFramesRendered);
      // On resume the surface may already be current without another paint.
      _send();
    } else {
      _binding.removeTimingsCallback(onFramesRendered);
      _cooldown?.cancel();
      _cooldown = null;
      _dirty = false;
    }
  }

  void onFramesRendered(List<FrameTiming> timings) {
    if (!_listening) return;
    _dirty = true;
    if (_cooldown == null) _send();
  }

  void _send() {
    if (!_listening) return;
    _dirty = false;
    unawaited(_notify());
    _cooldown = Timer(interval, () {
      _cooldown = null;
      if (_dirty) _send();
    });
  }

  Future<void> _notify() async {
    try {
      await onFrameReady();
    } catch (_) {
      // A detached activity/older native host must not break Flutter rendering.
    }
  }

  void dispose() {
    _disposed = true;
    _syncListening();
    _binding.removeObserver(this);
  }
}
