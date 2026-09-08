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
    final initial = tester.getRect(find.byKey(const ValueKey('video-card')));
    await tester.tap(find.byKey(const ValueKey('video-card')));
    await tester.pump();
    final frames = <List<double>>[];
    for (var step = 1; step <= 9; step++) {
      if (step == 1) {
        await tester.pump(const Duration(milliseconds: 16));
        final firstFrame = _frame(tester);
        expect(firstFrame[2], greaterThan(initial.width + 1));
        expect(firstFrame[3], greaterThan(initial.height + 1));
        expect(firstFrame[6], greaterThan(0));
        await tester.pump(
          videoPageTransitionDuration ~/ 10 - const Duration(milliseconds: 16),
        );
      } else {
        await tester.pump(videoPageTransitionDuration ~/ 10);
      }
      final frame = _frame(tester);
      expect(
        frame[2],
        greaterThanOrEqualTo(frames.isEmpty ? initial.width : frames.last[2]),
      );
      expect(
        frame[6],
        greaterThanOrEqualTo(frames.isEmpty ? 0.0 : frames.last[6]),
      );
      if (step >= 7) {
        // No clear-background flash at full screen or during page reveal.
        expect(frame[6], 1);
        expect(
          frame[2],
          closeTo(
            tester.view.physicalSize.width / tester.view.devicePixelRatio + 144,
            0.001,
          ),
        );
      }
      frames.add(frame);
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
      if (step == 9) {
        expect(_opacity(tester, 'video-transition-backdrop'), lessThan(0.2));
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
