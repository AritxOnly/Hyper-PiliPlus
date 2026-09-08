import 'package:PiliPlus/common/widgets/video_card/video_card_transition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('video card expands to the page and returns without errors', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _SourcePage()));

    await tester.tap(find.byKey(const ValueKey('video-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(BackdropFilter), findsOneWidget);
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
    Navigator.of(tester.element(find.text('播放页'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(BackdropFilter), findsOneWidget);
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
    expect(find.byKey(const ValueKey('video-card')), findsOneWidget);
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
              MaterialPageRoute<void>(builder: (_) => const _TargetPage()),
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

class _TargetPage extends StatelessWidget {
  const _TargetPage();

  @override
  Widget build(BuildContext context) {
    return VideoPageHeroTarget(
      tag: 'video-card-transition-test',
      surfaceColor: Theme.of(context).colorScheme.surface,
      child: const Scaffold(body: Center(child: Text('播放页'))),
    );
  }
}
