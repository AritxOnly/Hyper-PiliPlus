import 'package:PiliPlus/common/widgets/native_feedback.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(nativeFeedbackChannel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(
    () => messenger.setMockMethodCallHandler(nativeFeedbackChannel, null),
  );

  testWidgets(
    'native toast displays once, rebuild is harmless, disposal cancels by id',
    (tester) async {
      Widget app() => MaterialApp(
        home: NativeTextToast(
          message: '已保存',
          fallback: (_) => const Text('fallback'),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pump();
      await tester.pumpWidget(app());
      expect(calls.map((call) => call.method), ['showToast']);
      expect(find.text('fallback'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(calls.map((call) => call.method), ['showToast', 'cancelToast']);
      expect(calls.first.arguments['id'], calls.last.arguments['id']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('missing native plugin falls back to Flutter toast', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(nativeFeedbackChannel, (_) {
      throw MissingPluginException();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: NativeTextToast(
          message: '已保存',
          fallback: (_) => const Text('fallback'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('fallback'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'SmartDialog onlyRefresh replaces native text and cancels on dismissal',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: FlutterSmartDialog.init(
            toastBuilder: (msg) => NativeTextToast(
              key: ValueKey(msg),
              message: msg,
              fallback: (_) => Text(msg),
            ),
          ),
          home: const Scaffold(),
        ),
      );
      for (final message in ['first', 'second']) {
        SmartDialog.showToast(
          message,
          displayType: SmartToastType.onlyRefresh,
          displayTime: const Duration(seconds: 1),
        );
        await tester.pumpAndSettle();
      }
      expect(
        calls
            .where((call) => call.method == 'showToast')
            .map((call) => call.arguments['message']),
        ['first', 'second'],
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(calls.last.method, 'cancelToast');
      expect(calls.where((call) => call.method == 'cancelToast'), hasLength(2));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final dark in [false, true]) {
    for (final action in <String?>[null, 'more']) {
      testWidgets(
        'native copy preserves text and advanced actions: dark=$dark, action=$action',
        (tester) async {
          messenger.setMockMethodCallHandler(nativeFeedbackChannel, (
            call,
          ) async {
            calls.add(call);
            return action;
          });
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? ThemeData.dark() : ThemeData.light(),
              home: const Text('page'),
            ),
          );
          var more = 0;
          const text = '中文🙂\nhttps://example.com\n[表情]';
          expect(
            await showNativeCopyDialog(
              tester.element(find.text('page')),
              text,
              onMore: () => more++,
            ),
            isTrue,
          );
          expect(calls.single.method, 'showCopyText');
          expect(calls.single.arguments, {
            'text': text,
            'dark': dark,
            'more': true,
          });
          expect(more, action == 'more' ? 1 : 0);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  testWidgets('native copy falls back when unavailable', (tester) async {
    messenger.setMockMethodCallHandler(nativeFeedbackChannel, (_) {
      throw PlatformException(code: 'unavailable');
    });
    await tester.pumpWidget(const MaterialApp(home: Text('page')));
    expect(
      await showNativeCopyDialog(tester.element(find.text('page')), 'text'),
      isFalse,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('copy on iOS retains Flutter dialog', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('page')));
    expect(
      await showNativeCopyDialog(tester.element(find.text('page')), 'text'),
      isFalse,
    );
    expect(calls, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final selection in <int?>[null, 0, 1, 99]) {
    testWidgets('native action selection $selection', (tester) async {
      messenger.setMockMethodCallHandler(nativeFeedbackChannel, (call) async {
        calls.add(call);
        return selection;
      });
      await tester.pumpWidget(
        MaterialApp(theme: ThemeData.dark(), home: const Text('page')),
      );
      int? chosen;
      final handled = await showNativeActionMenu(
        tester.element(find.text('page')),
        [
          (label: '分享', onSelected: () => chosen = 0),
          (label: '保存', onSelected: () => chosen = 1),
        ],
      );
      expect(handled, isTrue);
      expect(chosen, selection == 99 ? null : selection);
      expect(calls.single.arguments['dark'], isTrue);
      expect(calls.single.arguments['items'], ['分享', '保存']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('non Android menu falls back without platform calls', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Text('page')));
    expect(
      await showNativeActionMenu(tester.element(find.text('page')), [
        (label: '保存', onSelected: () {}),
      ]),
      isFalse,
    );
    expect(calls, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
