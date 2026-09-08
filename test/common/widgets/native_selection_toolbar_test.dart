import 'dart:async';

import 'package:PiliPlus/common/widgets/native_selection_toolbar.dart';
import 'package:PiliPlus/common/widgets/selection_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late Completer<int?> response;
  setUp(() {
    calls.clear();
    response = Completer<int?>();
    messenger.setMockMethodCallHandler(nativeSelectionChannel, (call) async {
      calls.add(call);
      if (call.method == 'show') return response.future;
      return null;
    });
  });
  tearDown(
    () => messenger.setMockMethodCallHandler(nativeSelectionChannel, null),
  );

  Widget toolbar({
    double y = 50,
    VoidCallback? onAction,
    VoidCallback? onDismiss,
  }) => MaterialApp(
    home: NativeSelectionToolbar(
      anchors: TextSelectionToolbarAnchors(primaryAnchor: Offset(100, y)),
      onDismiss: onDismiss ?? () {},
      buttonItems: [
        ContextMenuButtonItem(label: '复制', onPressed: onAction ?? () {}),
      ],
    ),
  );

  testWidgets(
    'selection movement updates one native toolbar; disposal hides owner',
    (tester) async {
      await tester.pumpWidget(toolbar());
      await tester.pump();
      expect(calls.single.method, 'show');
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
      final id = calls.single.arguments['id'];
      await tester.pumpWidget(toolbar(y: 90));
      await tester.pump();
      expect(calls.last.method, 'update');
      expect(calls.last.arguments['id'], id);
      expect(
        calls.last.arguments['y'],
        greaterThan(calls.first.arguments['y']),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(calls.last.method, 'hide');
      expect(calls.last.arguments['id'], id);
      response.complete(null);
      await tester.pump();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'selected action runs Flutter callback and can reopen after select all',
    (tester) async {
      var actions = 0;
      await tester.pumpWidget(toolbar(onAction: () => actions++));
      await tester.pump();
      final first = response;
      response = Completer<int?>();
      await tester.runAsync(() async {
        first.complete(0);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      await tester.pump();
      expect(actions, 1);
      expect(calls.where((call) => call.method == 'show'), hasLength(2));
      await tester.pumpWidget(const SizedBox.shrink());
      response.complete(null);
      await tester.pump();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'system dismissal hides Flutter toolbar without selecting an action',
    (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(toolbar(onDismiss: () => dismissed++));
      await tester.pump();
      await tester.runAsync(() async {
        response.complete(null);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      expect(dismissed, 1);
      expect(calls.where((call) => call.method == 'show'), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('unavailable native toolbar falls back to Flutter', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(nativeSelectionChannel, (_) {
      throw PlatformException(code: 'unavailable');
    });
    await tester.pumpWidget(toolbar());
    await tester.pumpAndSettle();
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'Flutter dialog and selected text stay mounted under native toolbar',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Dialog(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: SelectionText('select this text'),
              ),
            ),
          ),
        ),
      );
      await tester.longPress(find.text('select this text'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(SelectionArea), findsOneWidget);
      expect(calls.where((call) => call.method == 'show'), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      response.complete(null);
      await tester.pump();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('iOS retains its Flutter adaptive toolbar', (tester) async {
    await tester.pumpWidget(toolbar());
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    expect(calls, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
