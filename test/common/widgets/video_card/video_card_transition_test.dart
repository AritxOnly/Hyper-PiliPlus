import 'package:PiliPlus/common/widgets/video_card/video_card_transition.dart';
import 'package:PiliPlus/common/widgets/route_aware_mixin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('video card expands to the page and returns without errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        navigatorObservers: [routeObserver],
        builder: (context, child) => RepaintBoundary(
          key: videoTransitionCaptureBoundaryKey,
          child: child!,
        ),
        home: const _SourcePage(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('video-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SnapshotWidget), findsOneWidget);
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('video-transition-backdrop')),
          )
          .opacity
          .value,
      1,
    );
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('video-transition-page')),
          )
          .opacity
          .value,
      0,
    );
    expect(find.byType(FittedBox), findsNothing);
    expect(tester.takeException(), isNull);

    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(
              const ValueKey('video-transition-page-surface-opacity'),
            ),
          )
          .opacity
          .value,
      0,
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('video-transition-backdrop')),
          )
          .opacity
          .value,
      inExclusiveRange(0, 1),
    );
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(
              const ValueKey('video-transition-page-surface-opacity'),
            ),
          )
          .opacity
          .value,
      inExclusiveRange(0, 1),
    );
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('video-transition-page')),
          )
          .opacity
          .value,
      0,
    );

    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('video-transition-backdrop')),
          )
          .opacity
          .value,
      0,
    );
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(
              const ValueKey('video-transition-page-surface-opacity'),
            ),
          )
          .opacity
          .value,
      1,
    );
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('video-transition-page')),
          )
          .opacity
          .value,
      inExclusiveRange(0, 1),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(Get.routing.route, isA<GetPageRoute>());
    expect(Get.currentRoute, '/videoV');
    expect(Get.arguments['heroTag'], 'video-card-transition-test');
    expect(Get.isRegistered<_PlaybackProbeController>(), isTrue);
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('video-transition-page')),
          )
          .opacity
          .value,
      1,
    );
    Navigator.of(tester.element(find.text('播放页'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('video-transition-page')),
          )
          .opacity
          .value,
      inExclusiveRange(0, 1),
    );
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('video-transition-page')),
          )
          .opacity
          .value,
      0,
    );
    expect(find.byType(FittedBox), findsNothing);

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('video-card')), findsOneWidget);
    expect(Get.isRegistered<_PlaybackProbeController>(), isFalse);
  });
}

class _SourcePage extends StatelessWidget {
  const _SourcePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: VideoCardHero(
          tag: 'video-card-transition-test',
          child: InkWell(
            key: const ValueKey('video-card'),
            onTap: () => Navigator.of(context).push(
              VideoPageTransitionRoute<void>(
                settings: const RouteSettings(
                  name: '/videoV',
                  arguments: {'heroTag': 'video-card-transition-test'},
                ),
                builder: (_) => const _TargetPage(),
              ),
            ),
            child: const SizedBox(
              width: 180,
              height: 120,
              child: ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    );
  }
}

class _TargetPage extends StatefulWidget {
  const _TargetPage();

  @override
  State<_TargetPage> createState() => _TargetPageState();
}

class _TargetPageState extends State<_TargetPage>
    with RouteAware, RouteAwareMixin {
  @override
  void initState() {
    super.initState();
    Get.put(_PlaybackProbeController());
  }

  @override
  Widget build(BuildContext context) {
    return VideoPageHeroTarget(
      tag: 'video-card-transition-test',
      surfaceColor: Theme.of(context).colorScheme.surface,
      child: const Scaffold(body: Center(child: Text('播放页'))),
    );
  }
}

class _PlaybackProbeController extends GetxController {}
