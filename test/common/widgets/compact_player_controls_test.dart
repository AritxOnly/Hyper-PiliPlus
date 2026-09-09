import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/compact_player_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final height in [40.0, 44.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('menu label centered at height=$height scale=$scale', (
        tester,
      ) async {
        const target = ValueKey('menu-target');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SizedBox(
                    width: 76,
                    height: height,
                    child: PopupMenuButton<int>(
                      key: target,
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 1, child: Text('选择')),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: PlayerControlLabel(
                          child: Text('1.25X', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final bounds = tester.getRect(find.byKey(target));
        final label = tester.getRect(find.text('1.25X'));
        expect(label.center.dy, closeTo(bounds.center.dy, .01));
        expect(label.center.dx, closeTo(bounds.center.dx, .01));
        // The alignment wrapper must not shrink the menu's hit target.
        await tester.tapAt(bounds.topLeft + const Offset(3, 3));
        await tester.pumpAndSettle();
        expect(find.text('选择'), findsOneWidget);
      });
    }
  }

  testWidgets('time label centers within an option tile', (tester) async {
    const target = ValueKey('time-target');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: target,
              width: 76,
              height: 44,
              child: PlayerControlLabel(
                child: Text(
                  '01:23 / 04:56',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getCenter(find.text('01:23 / 04:56')).dy,
      tester.getCenter(find.byKey(target)).dy,
    );
  });

  Widget app(
    double width,
    double scale, {
    VoidCallback? play,
    VoidCallback? fullscreen,
    ValueChanged<int>? seek,
    VoidCallback? option,
  }) => MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xff353742),
      body: Center(
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: SizedBox(
            width: width,
            child: CompactPlayerControls(
              playButton: IconButton(
                tooltip: '播放',
                onPressed: play ?? () {},
                icon: const Icon(Icons.play_arrow),
              ),
              progress: ProgressBar(
                key: const ValueKey('progress'),
                progress: 20,
                buffered: 50,
                total: 100,
                onSeek: seek,
                onDragStart: (_) {},
                thumbRadius: 7,
                thumbGlowRadius: 18,
                baseBarColor: Colors.white24,
                progressBarColor: Colors.blue,
                bufferedBarColor: Colors.blueGrey,
                thumbColor: Colors.blue,
                thumbGlowColor: Colors.blueAccent,
              ),
              time: const Text(
                '01:23:45 / 02:34:56',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11),
              ),
              speed: const Text('1.25X'),
              fullscreenButton: IconButton(
                tooltip: '全屏',
                onPressed: fullscreen ?? () {},
                icon: const Icon(Icons.fullscreen),
              ),
              options: () => [
                (
                  label: '字幕',
                  control: IconButton(
                    tooltip: '字幕设置',
                    onPressed: option ?? () {},
                    icon: const Icon(Icons.subtitles),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  for (final width in [240.0, 320.0, 390.0, 640.0, 1024.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('single row fits width=$width scale=$scale', (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(app(width, scale));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(CompactPlayerControls)).height, 48);
        expect(
          tester.getSize(find.byKey(const ValueKey('progress'))).width,
          greaterThan(30),
        );
        expect(
          find.text('1.25X'),
          width >= 440 ? findsOneWidget : findsNothing,
        );
      });
    }
  }

  testWidgets('primary actions and seeking remain usable', (tester) async {
    var play = 0;
    var fullscreen = 0;
    int? position;
    await tester.pumpWidget(
      app(
        390,
        1,
        play: () => play++,
        fullscreen: () => fullscreen++,
        seek: (value) => position = value,
      ),
    );
    await tester.tap(find.byTooltip('播放'));
    await tester.tap(find.byTooltip('全屏'));
    final rail = tester.getRect(find.byKey(const ValueKey('progress')));
    final drag = await tester.startGesture(
      Offset(rail.left + rail.width * .25, rail.center.dy),
    );
    await drag.moveTo(Offset(rail.left + rail.width * .75, rail.center.dy));
    await drag.up();
    await tester.pumpAndSettle();
    expect(play, 1);
    expect(fullscreen, 1);
    expect(position, inInclusiveRange(70000, 80000));
  });

  testWidgets('secondary controls remain reachable and panel closes', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(app(320, 1, option: () => selected++));
    await tester.tap(find.byTooltip('播放选项'));
    await tester.pumpAndSettle();
    expect(find.text('字幕'), findsOneWidget);
    await tester.tap(find.byTooltip('字幕设置'));
    expect(selected, 1);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}
