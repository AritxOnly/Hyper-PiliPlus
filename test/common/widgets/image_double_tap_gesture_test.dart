import 'package:PiliPlus/common/widgets/gesture/image_double_tap_gesture_recognizer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('double tap callback observes the second pointer up timestamp', (
    tester,
  ) async {
    late ImageDoubleTapGestureRecognizer recognizer;
    Duration? callbackTime;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            ImageDoubleTapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  ImageDoubleTapGestureRecognizer
                >(
                  () => recognizer = ImageDoubleTapGestureRecognizer(),
                  (instance) => instance.onDoubleTap = () {
                    callbackTime = instance.timeStamp;
                  },
                ),
          },
          child: const SizedBox.expand(),
        ),
      ),
    );
    final first = await tester.createGesture();
    await first.down(
      const Offset(100, 100),
      timeStamp: const Duration(milliseconds: 10),
    );
    await first.up(timeStamp: const Duration(milliseconds: 30));
    await tester.pump(const Duration(milliseconds: 80));
    final second = await tester.createGesture();
    await second.down(
      const Offset(100, 100),
      timeStamp: const Duration(milliseconds: 110),
    );
    await second.up(timeStamp: const Duration(milliseconds: 140));
    expect(callbackTime, const Duration(milliseconds: 140));
    expect(recognizer.timeStamp, callbackTime);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing during a pointer sequence removes the observer', (
    tester,
  ) async {
    final recognizer = ImageDoubleTapGestureRecognizer()
      ..onDoubleTap = () {}
      ..addPointer(
        const PointerDownEvent(pointer: 42, position: Offset(20, 20)),
      )
      ..dispose();
    GestureBinding.instance.pointerRouter.route(
      const PointerUpEvent(pointer: 42, timeStamp: Duration(milliseconds: 50)),
    );
    expect(recognizer.timeStamp, Duration.zero);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
