import 'package:PiliPlus/common/widgets/scroll_position_bookmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final offset in [80.0, 850.0]) {
    testWidgets('nested reply return restores combined offset $offset', (
      tester,
    ) async {
      final nestedKey = GlobalKey<NestedScrollViewState>();
      final navigator = GlobalKey<NavigatorState>();
      late BuildContext listContext;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: NestedScrollView(
              key: nestedKey,
              headerSliverBuilder: (_, _) => [
                const SliverToBoxAdapter(child: SizedBox(height: 200)),
              ],
              body: CustomScrollView(
                slivers: [
                  SliverList.builder(
                    itemCount: 100,
                    itemBuilder: (context, index) {
                      listContext = context;
                      return SizedBox(height: 60, child: Text('评论 $index'));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final nested = nestedKey.currentState!;
      nested.outerController.jumpTo(offset);
      await tester.pumpAndSettle();
      final outer = nested.outerController.offset;
      final inner = nested.innerController.offset;
      final bookmark = ScrollPositionBookmark.capture(listContext);
      final route = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('二级评论')),
      );
      navigator.currentState!.push(route).then((_) => bookmark.restore());
      await tester.pumpAndSettle();
      // Simulate an offset change while the source route is covered.
      nested.outerController.jumpTo(0);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(nested.outerController.offset, closeTo(outer, .01));
      expect(nested.innerController.offset, closeTo(inner, .01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      bookmark.restore();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ordinary list restores and clamps after content shrinks', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    late BuildContext listContext;
    Widget app(int count) => MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          controller: controller,
          itemCount: count,
          itemBuilder: (context, index) {
            listContext = context;
            return SizedBox(height: 60, child: Text('$index'));
          },
        ),
      ),
    );
    await tester.pumpWidget(app(100));
    controller.jumpTo(850);
    await tester.pumpAndSettle();
    final bookmark = ScrollPositionBookmark.capture(listContext);
    controller.jumpTo(0);
    bookmark.restore();
    await tester.pumpAndSettle();
    expect(controller.offset, 850);
    await tester.pumpWidget(app(12));
    bookmark.restore();
    await tester.pumpAndSettle();
    expect(controller.offset, controller.position.maxScrollExtent);
    expect(tester.takeException(), isNull);
  });
}
