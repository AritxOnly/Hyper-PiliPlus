import 'dart:io';

import 'package:PiliPlus/common/widgets/player_bar.dart';
import 'package:PiliPlus/pages/setting/models/play_settings.dart';
import 'package:PiliPlus/plugin/pl_player/models/player_control_layout.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/compact_player_controls.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/player_control_layout.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('player-layout-test-');
    Hive.init(directory.path);
    GStorage.setting = await Hive.openBox('setting');
    GStorage.video = await Hive.openBox('video');
    GStorage.localCache = await Hive.openBox('localCache');
  });
  setUp(() => GStorage.setting.clear());
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('missing or unknown saved layouts retain the compact default', () async {
    expect(Pref.playerControlLayout, PlayerControlLayout.compact);
    for (final value in ['unknown', 1, false, <int>[]]) {
      await GStorage.setting.put(SettingBoxKey.playerControlLayout, value);
      expect(Pref.playerControlLayout, PlayerControlLayout.compact);
    }
  });

  testWidgets(
    'settings dropdown saves and switches controls without recreating playback',
    (tester) async {
      await tester.runAsync(() async {
        var creations = 0;
        Future<void> open() => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  playSettings.first.widget,
                  _PlaybackProbe(onCreate: () => creations++),
                  PlayerControlLayoutBuilder(
                    builder: (_, layout) => SizedBox(
                      width: 320,
                      child: layout == PlayerControlLayout.compact
                          ? CompactPlayerControls(
                              playButton: const Icon(Icons.play_arrow),
                              progress: const SizedBox(height: 24),
                              time: const Text('01:23 / 12:34'),
                              speed: const Text('1.0X'),
                              options: (_) => [],
                            )
                          : const UpstreamPlayerControls(
                              progress: SizedBox(height: 24),
                              controls: Text('双行操作区'),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await open();
        await tester.pumpAndSettle();
        expect(find.byType(CompactPlayerControls), findsOneWidget);
        await tester.tap(find.text('播放器布局'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('上游双行'));
        await tester.pumpAndSettle();
        expect(find.byType(UpstreamPlayerControls), findsOneWidget);
        expect(find.byType(CompactPlayerControls), findsNothing);
        expect(creations, 1);
        expect(
          GStorage.setting.get(SettingBoxKey.playerControlLayout),
          'upstream',
        );
        await GStorage.setting.flush();
        await tester.pumpWidget(const SizedBox.shrink());
        await open();
        await tester.pumpAndSettle();
        expect(find.byType(UpstreamPlayerControls), findsOneWidget);
        await tester.tap(find.text('播放器布局'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('紧凑单行'));
        await tester.pumpAndSettle();
        expect(find.byType(CompactPlayerControls), findsOneWidget);
        expect(
          GStorage.setting.get(SettingBoxKey.playerControlLayout),
          'compact',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await GStorage.setting.put(
          SettingBoxKey.playerControlLayout,
          'upstream',
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    },
  );

  for (final width in [240.0, 320.0, 640.0, 1024.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('upstream rows fit and remain clickable at $width / $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var clicks = 0;
        const progressKey = ValueKey('progress');
        const actionKey = ValueKey('action');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SizedBox(
                    width: width,
                    child: UpstreamPlayerControls(
                      progress: const SizedBox(
                        key: progressKey,
                        height: 24,
                        width: double.infinity,
                      ),
                      controls: PlayerBar(
                        left: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.play_arrow),
                            ),
                            const Text('01:23\n12:34'),
                          ],
                        ),
                        right: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('1.25X'),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.subtitles),
                            ),
                            IconButton(
                              key: actionKey,
                              onPressed: () => clicks++,
                              icon: const Icon(Icons.fullscreen),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(
          tester.getRect(find.byKey(progressKey)).bottom,
          lessThan(tester.getRect(find.byType(PlayerBar)).top),
        );
        expect(
          tester.getSize(find.byKey(progressKey)).width,
          closeTo(width - 40, .01),
        );
        await tester.tap(find.byKey(actionKey));
        expect(clicks, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _PlaybackProbe extends StatefulWidget {
  const _PlaybackProbe({required this.onCreate});
  final VoidCallback onCreate;
  @override
  State<_PlaybackProbe> createState() => _PlaybackProbeState();
}

class _PlaybackProbeState extends State<_PlaybackProbe> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
