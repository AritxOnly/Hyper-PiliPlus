import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/pages/video/widgets/landscape_geometry.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/app_bar_ani.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final size in [
    const Size(740, 360),
    const Size(900, 600),
    const Size(1200, 800),
  ]) {
    testWidgets('landscape panel keeps readable width at $size', (
      tester,
    ) async {
      tester.view.reset();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const side = ValueKey('comments');
      const player = ValueKey('player');
      final available = size.width - 48;
      final width = landscapePlayerWidth(
        available,
        (size.height - 24) * 16 / 9,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                SizedBox(key: player, width: width),
                SizedBox(key: side, width: available - width),
              ],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(side)).width, greaterThanOrEqualTo(320));
      expect(tester.getRect(find.byKey(side)).right, size.width - 24);
      expect(
        tester.getRect(find.byKey(player)).right,
        tester.getRect(find.byKey(side)).left,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'immersive body extends under status bar and can restore insets',
    (tester) async {
      const body = ValueKey('body');
      Future<void> pump(bool immersive) => tester.pumpWidget(
        MaterialApp(
          home: SimpleScaffold(
            extendBodyBehindAppBar: immersive,
            appBar: const SizedBox(height: 28),
            body: const SizedBox.expand(key: body),
          ),
        ),
      );
      await pump(true);
      expect(tester.getTopLeft(find.byKey(body)).dy, 0);
      await pump(false);
      expect(tester.getTopLeft(find.byKey(body)).dy, 28);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 1.8]) {
    testWidgets('immersive controls stay below status bar at scale $scale', (
      tester,
    ) async {
      final controller = AnimationController(vsync: tester, value: 1);
      addTearDown(controller.dispose);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              viewPadding: const EdgeInsets.only(top: 28),
              textScaler: TextScaler.linear(scale),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: AppBarAni(
                controller: controller,
                isTop: true,
                isFullScreen: false,
                removeSafeArea: false,
                topSafeArea: true,
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('返回'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getTopLeft(find.byType(TextButton)).dy, 28);
      await tester.tap(find.byType(TextButton));
      expect(taps, 1);
    });
  }
}
