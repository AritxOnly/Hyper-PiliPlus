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
  setUp(() {
    _PlaybackProbeController.creations = 0;
    _ContentProbeState.creations = 0;
  });
  tearDown(Get.reset);
  predictiveBackTests();
  for (final preserveChildHeroes in [false, true]) {
    testWidgets(
      'return content handoff (nested Heroes: $preserveChildHeroes)',
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
            home: _SourcePage(preserveChildHeroes: preserveChildHeroes),
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
        expect(
          find.byKey(const ValueKey('video-transition-dim')),
          findsNothing,
        );
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
          final returnCard = find.byKey(
            const ValueKey('video-transition-return-card'),
          );
          final returnRect = tester.getRect(returnCard);
          expect(returnRect.left, closeTo(rect.left, 0.001));
          expect(returnRect.top, closeTo(rect.top, 0.001));
          expect(returnRect.width, closeTo(rect.width, 0.001));
          expect(returnRect.height, closeTo(rect.height, 0.001));
          final cardOpacity = tester
              .widget<Opacity>(
                find.byKey(
                  const ValueKey('video-transition-return-card-opacity'),
                ),
              )
              .opacity;
          expect(cardOpacity + opacity, closeTo(1, 0.001));
          if (contraction >= 0.5) expect(cardOpacity, greaterThan(0.85));
          expect(
            find.descendant(
              of: returnCard,
              matching: find.byKey(const ValueKey('video-card')),
            ),
            findsOneWidget,
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
}

void predictiveBackTests() {
  for (final cancel in [false, true]) {
    testWidgets('predictive back continues once (cancel: $cancel)', (
      tester,
    ) async {
      await tester.pumpWidget(
        GetMaterialApp(
          navigatorObservers: [routeObserver],
          home: const _SourcePage(preserveChildHeroes: false),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('video-card')));
      await tester.pumpAndSettle();
      final route = Get.routing.route as VideoPageTransitionRoute<void>;
      final owner = route.navigator!;
      final page = find.byKey(
        const ValueKey('video-transition-page-container'),
      );
      final full = tester.getRect(page);
      route
        ..handleStartBackGesture(progress: 1)
        ..handleUpdateBackGestureProgress(progress: 0.55);
      await tester.pump();
      final dragged = tester.getRect(page);
      expect(dragged.width, lessThan(full.width));
      expect(find.byKey(const ValueKey('video-transition-dim')), findsNothing);
      if (cancel) {
        route.handleCancelBackGesture();
        await tester.pumpAndSettle();
        expect(route.isCurrent, isTrue);
        expect(owner.userGestureInProgress, isFalse);
        expect(tester.getRect(page), full);
        expect(_pageOpacity(tester), 1);
        // Cancelling must not prevent a later, successful gesture.
        route
          ..handleStartBackGesture(progress: 1)
          ..handleUpdateBackGestureProgress(progress: 0.55);
        await tester.pump();
      }
      route.handleCommitBackGesture();
      expect(route.animation!.value, closeTo(0.55, 0.001));
      route.handleCommitBackGesture(); // repeated platform callback is ignored
      await tester.pump();
      var previousWidth = dragged.width;
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        final width = tester.getRect(page).width;
        expect(width, lessThanOrEqualTo(previousWidth));
        previousWidth = width;
      }
      await tester.pumpAndSettle();
      expect(owner.userGestureInProgress, isFalse);
      expect(find.byKey(const ValueKey('video-card')), findsOneWidget);
      expect(Get.isRegistered<_PlaybackProbeController>(), isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}

class _SourcePage extends StatelessWidget {
  const _SourcePage({required this.preserveChildHeroes});
  final bool preserveChildHeroes;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: VideoCardHero(
        tag: 'video-card-transition-test',
        surfaceColor: Theme.of(context).cardColor,
        preserveChildHeroes: preserveChildHeroes,
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
          child: SizedBox(
            width: 180,
            height: 120,
            child: preserveChildHeroes
                ? const Hero(
                    tag: 'nested-image',
                    child: ColoredBox(color: Colors.blue),
                  )
                : const ColoredBox(color: Colors.blue),
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
