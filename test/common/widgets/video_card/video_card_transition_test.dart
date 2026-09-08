import 'package:PiliPlus/common/widgets/video_card/video_card_transition.dart';
import 'package:PiliPlus/common/widgets/route_aware_mixin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

double _opacity(WidgetTester tester, String key) =>
    tester.widget<FadeTransition>(find.byKey(ValueKey(key))).opacity.value;

// Compare rendered geometry and visible layers at identical route progress.
List<double> _frame(WidgetTester tester) {
  final flight = find.byKey(const ValueKey('video-transition-flight'));
  final rect = tester.getRect(flight);
  final radius = tester.widget<ClipRRect>(flight).borderRadius as BorderRadius;
  return [
    rect.left,
    rect.top,
    rect.width,
    rect.height,
    radius.topLeft.x,
    _opacity(tester, 'video-transition-page'),
    _opacity(tester, 'video-transition-backdrop'),
    _opacity(tester, 'video-transition-page-surface-opacity'),
    tester
        .widget<ColoredBox>(
          find
              .descendant(
                of: flight,
                matching: find.byType(ColoredBox),
              )
              .first,
        )
        .color
        .a,
  ];
}

void main() {
  tearDown(Get.reset);
  testWidgets('enter and exit render the same frames in reverse', (
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
    final frames = <List<double>>[];
    for (var step = 1; step <= 9; step++) {
      await tester.pump(videoPageTransitionDuration ~/ 10);
      frames.add(_frame(tester));
      expect(tester.takeException(), isNull);
    }
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.byType(FittedBox), findsNothing);
    await tester.pumpAndSettle();
    expect(Get.routing.route, isA<GetPageRoute>());
    expect(Get.currentRoute, '/videoV');
    expect(Get.arguments['heroTag'], 'video-card-transition-test');
    expect(Get.isRegistered<_PlaybackProbeController>(), isTrue);
    expect(_opacity(tester, 'video-transition-page'), 1);

    Navigator.of(tester.element(find.text('播放页'))).pop();
    await tester.pump();
    for (var step = 1; step <= 9; step++) {
      await tester.pump(videoPageReverseTransitionDuration ~/ 10);
      final reverse = _frame(tester);
      final forward = frames[9 - step];
      for (var field = 0; field < forward.length; field++) {
        expect(
          reverse[field],
          closeTo(forward[field], 0.001),
          reason: 'progress ${1 - step / 10}, field $field',
        );
      }
      if (step >= 7) {
        expect(_opacity(tester, 'video-transition-backdrop'), 0);
      }
      expect(tester.takeException(), isNull);
    }
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
