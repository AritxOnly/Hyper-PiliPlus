import 'dart:async';

import 'package:PiliPlus/utils/android/android_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Native chrome sits above Flutter's overlay. Use independent leases so nested
/// sheets/toasts cannot restore it while another foreground surface is visible.
abstract final class NativeNavigationOcclusion {
  static final Set<Object> _owners = {};

  static VoidCallback acquire() {
    final owner = Object();
    final wasEmpty = _owners.isEmpty;
    _owners.add(owner);
    if (wasEmpty) _sync(true);
    return () {
      if (_owners.remove(owner) && _owners.isEmpty) _sync(false);
    };
  }

  static void _sync(bool occluded) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      unawaited(PiliAndroidHelper.setMiuixOverlayOccluded(occluded));
    }
  }
}

class NativeNavigationPopupObserver extends NavigatorObserver {
  final Map<Route<dynamic>, VoidCallback> _releases = {};

  void _track(Route<dynamic>? route) {
    if (route is! PopupRoute || _releases.containsKey(route)) return;
    _releases[route] = NativeNavigationOcclusion.acquire();
    // completed waits for the reverse animation and overlay removal.
    unawaited(
      route.completed.whenComplete(() => _releases.remove(route)?.call()),
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _track(newRoute);
}

class NativeNavigationForeground extends StatefulWidget {
  const NativeNavigationForeground({super.key, required this.child});
  final Widget child;

  @override
  State<NativeNavigationForeground> createState() =>
      _NativeNavigationForegroundState();
}

class _NativeNavigationForegroundState
    extends State<NativeNavigationForeground> {
  late final VoidCallback _release;

  @override
  void initState() {
    super.initState();
    _release = NativeNavigationOcclusion.acquire();
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
