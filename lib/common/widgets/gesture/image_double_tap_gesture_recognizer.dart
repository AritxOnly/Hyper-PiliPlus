import 'package:flutter/gestures.dart';

class ImageDoubleTapGestureRecognizer extends DoubleTapGestureRecognizer {
  ImageDoubleTapGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  Duration timeStamp = .zero;
  final Set<int> _observedPointers = {};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    // Register before the SDK recognizer so onDoubleTap sees the current up time.
    _observedPointers.add(event.pointer);
    GestureBinding.instance.pointerRouter.addRoute(
      event.pointer,
      _observePointer,
    );
    super.addAllowedPointer(event);
  }

  void _observePointer(PointerEvent event) {
    if (event is PointerUpEvent) timeStamp = event.timeStamp;
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      GestureBinding.instance.pointerRouter.removeRoute(
        event.pointer,
        _observePointer,
      );
      _observedPointers.remove(event.pointer);
    }
  }

  @override
  void dispose() {
    for (final pointer in _observedPointers) {
      GestureBinding.instance.pointerRouter.removeRoute(
        pointer,
        _observePointer,
      );
    }
    _observedPointers.clear();
    super.dispose();
  }
}
