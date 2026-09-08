import 'package:PiliPlus/common/widgets/video_card/video_card_transition.dart';
import 'package:PiliPlus/common/widgets/route_aware_mixin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

double _pageOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(find.byKey(const ValueKey('video-transition-page')))
    .opacity
    .value;

void main() {
  tearDown(Get.reset);
  testWidgets(
    'reveal mid-entry, fade while shrinking and interpolate surfaces',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData(
            cardColor: const Color(0xffbbaa77),
            canvasColor: const Color(0xff223344),
          ),
          navigatorObservers: [routeObserver],
          home: const _SourcePage(),
        ),
      );
      final card = find.byKey(const ValueKey('video-card'));
      final initial = tester.getRect(card);
      final cardColor = Theme.of(tester.element(card)).cardColor;
      final pageColor = Theme.of(tester.element(card)).canvasColor;
      await tester.tap(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final flight = find.byKey(const ValueKey('video-transition-flight'));
      expect(tester.getRect(flight).width, greaterThan(initial.width + 1));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ImageFiltered), findsNothing);
      expect(find.byType(SnapshotWidget), findsNothing);
      expect(find.byType(RawImage), findsNothing);
      expect(
        find.byKey(const ValueKey('video-transition-dim')),
        findsOneWidget,
      );
      expect(_pageOpacity(tester), 0);
      final firstSurface = tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('video-transition-surface')),
          )
          .color;
      expect(firstSurface, isNot(cardColor));
      expect(firstSurface, isNot(pageColor));
      expect(
        tester
            .widget<ColoredBox>(
              find.byKey(const ValueKey('video-transition-flight-surface')),
            )
            .color,
        firstSurface,
      );
      await tester.pump(const Duration(milliseconds: 264)); // 50% of entry
      expect(_pageOpacity(tester), greaterThan(0));
      expect(_pageOpacity(tester), lessThan(1));
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // expansion complete
      expect(_pageOpacity(tester), 1);
      expect(
        tester
            .widget<ColoredBox>(
              find.byKey(const ValueKey('video-transition-surface')),
            )
            .color,
        pageColor,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('video-transition-dim')), findsNothing);
      expect(Get.routing.route, isA<GetPageRoute>());
      expect(Get.currentRoute, '/videoV');
      expect(Get.arguments['heroTag'], 'video-card-transition-test');
      expect(Get.isRegistered<_PlaybackProbeController>(), isTrue);
      expect(_PlaybackProbeController.creations, 1);
      expect(_ContentProbeState.creations, 1);
      final page = find.byKey(
        const ValueKey('video-transition-page-container'),
      );
      final full = tester.getRect(page);
      Navigator.of(tester.element(find.text('播放页'))).pop();
      await tester.pump();
      var previous = full;
      var previousOpacity = 1.0;
      for (var step = 1; step <= 10; step++) {
        await tester.pump(
          step == 1
              ? const Duration(milliseconds: 16)
              : const Duration(milliseconds: 50),
        );
        final rect = tester.getRect(page);
        expect(rect.width, lessThan(previous.width));
        expect(rect.height, lessThan(previous.height));
        final opacity = _pageOpacity(tester);
        expect(opacity, lessThan(previousOpacity));
        final contraction =
            (full.width - rect.width) / (full.width - initial.width);
        expect(
          opacity,
          closeTo(1 - Curves.easeOutCubic.transform(contraction), 0.001),
        );
        if (contraction >= 0.5) expect(opacity, lessThan(0.15));
        expect(
          tester
              .widget<ColoredBox>(
                find.byKey(const ValueKey('video-transition-surface')),
              )
              .color
              .toARGB32(),
          Color.lerp(cardColor, pageColor, 1 - contraction)!.toARGB32(),
        );
        previousOpacity = opacity;
        expect(
          find.byKey(const ValueKey('video-transition-dim')),
          findsNothing,
        );
        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.byType(ImageFiltered), findsNothing);
        expect(
          find.byKey(const ValueKey('video-transition-flight')),
          findsNothing,
        );
        expect(_PlaybackProbeController.creations, 1);
        expect(_ContentProbeState.creations, 1);
        expect(tester.takeException(), isNull);
        previous = rect;
      }
      expect(previous.center.dx, closeTo(initial.center.dx, 1));
      expect(previous.width, closeTo(initial.width, 5));
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      expect(Get.isRegistered<_PlaybackProbeController>(), isFalse);
    },
  );
}

class _SourcePage extends StatelessWidget {
  const _SourcePage();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: VideoCardHero(
        tag: 'video-card-transition-test',
        surfaceColor: Theme.of(context).cardColor,
        preserveChildHeroes: true,
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
            child: Hero(
              tag: 'nested-image',
              child: ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    ),
  );
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
  Widget build(BuildContext context) => VideoPageHeroTarget(
    tag: 'video-card-transition-test',
    surfaceColor: Theme.of(context).canvasColor,
    child: const _ContentProbe(),
  );
}

class _PlaybackProbeController extends GetxController {
  _PlaybackProbeController() {
    creations++;
  }
  static int creations = 0;
}

class _ContentProbe extends StatefulWidget {
  const _ContentProbe();

  @override
  State<_ContentProbe> createState() => _ContentProbeState();
}

class _ContentProbeState extends State<_ContentProbe> {
  static int creations = 0;

  @override
  void initState() {
    super.initState();
    creations++;
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('播放页')));
}
