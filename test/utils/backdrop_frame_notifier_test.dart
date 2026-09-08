import 'package:PiliPlus/utils/android/backdrop_frame_notifier.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BackdropFrameNotifier notifier;
  var requests = 0;
  setUp(() => requests = 0);
  tearDown(() => notifier.dispose());

  BackdropFrameNotifier create() => BackdropFrameNotifier(
    onFrameReady: () async {
      requests++;
    },
  );

  testWidgets('a late refreshed frame wakes sampling after idle', (
    tester,
  ) async {
    notifier = create()..configure(visible: true);
    expect(requests, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(requests, 1); // No polling after touch/frames stop.
    notifier.onFramesRendered(const []);
    expect(requests, 2); // Network/image result needs no new touch.
    await tester.pump(const Duration(seconds: 5));
    expect(requests, 2);
  });

  testWidgets('frame bursts are coalesced and the last frame is captured', (
    tester,
  ) async {
    notifier = create()..configure(visible: true);
    for (var i = 0; i < 20; i++) {
      notifier.onFramesRendered(const []);
    }
    expect(requests, 1);
    await tester.pump(BackdropFrameNotifier.interval);
    expect(requests, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(requests, 2);
  });

  testWidgets(
    'transition pause cancels trailing capture and resumes with a fresh sample',
    (tester) async {
      notifier = create()
        ..configure(visible: true)
        ..onFramesRendered(const [])
        ..configure(paused: true);
      await tester.pump(const Duration(seconds: 1));
      notifier.onFramesRendered(const []);
      expect(requests, 1);
      notifier.configure(paused: false);
      expect(requests, 2);
      notifier.configure(paused: false);
      expect(requests, 2); // Idempotent state updates.
      notifier.dispose();
    },
  );

  testWidgets('visibility and occlusion independently gate sampling', (
    tester,
  ) async {
    notifier = create()
      ..configure(visible: true, occluded: true)
      ..onFramesRendered(const []);
    expect(requests, 0);
    notifier.configure(occluded: false);
    expect(requests, 1);
    notifier
      ..configure(visible: false, paused: true)
      ..configure(paused: false);
    await tester.pump(const Duration(seconds: 1));
    notifier.onFramesRendered(const []);
    expect(requests, 1);
    notifier.configure(visible: true);
    expect(requests, 2);
    notifier.dispose();
  });

  testWidgets(
    'backgrounding cancels timers and resume refreshes idle surface',
    (tester) async {
      notifier = create()
        ..configure(visible: true)
        ..onFramesRendered(const [])
        ..didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 1));
      notifier.onFramesRendered(const []);
      expect(requests, 1);
      notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(requests, 2);
      notifier.dispose();
    },
  );

  testWidgets('dispose removes pending work and ignores future frames', (
    tester,
  ) async {
    notifier = create()
      ..configure(visible: true)
      ..onFramesRendered(const [])
      ..dispose();
    await tester.pump(const Duration(seconds: 1));
    notifier
      ..onFramesRendered(const [])
      ..configure(visible: true);
    expect(requests, 1);
  });

  testWidgets('native bridge failures do not escape into frame handling', (
    tester,
  ) async {
    notifier = BackdropFrameNotifier(
      onFrameReady: () {
        throw StateError('detached');
      },
    )..configure(visible: true);
    await tester.pump(BackdropFrameNotifier.interval);
    notifier.onFramesRendered(const []);
    await tester.pump(BackdropFrameNotifier.interval);
    expect(tester.takeException(), isNull);
  });
}
