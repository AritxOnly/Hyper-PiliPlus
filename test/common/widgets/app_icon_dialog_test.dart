import 'dart:async';
import 'dart:ui' as ui;

import 'package:PiliPlus/models/common/app_icon_style.dart';
import 'package:PiliPlus/pages/setting/widgets/app_icon_dialog.dart';
import 'package:PiliPlus/utils/android/app_icon.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late String nativeStyle;
  bool fail = false;
  Completer<void>? pending;
  final settings = _MemorySettings();

  setUpAll(() => GStorage.setting = settings);

  setUp(() {
    calls = [];
    nativeStyle = 'system';
    fail = false;
    pending = null;
    settings._entries.clear();
    messenger.setMockMethodCallHandler(appIconChannel, (call) async {
      calls.add(call);
      if (call.method == 'set') {
        await pending?.future;
        if (fail) throw PlatformException(code: 'icon_unavailable');
        nativeStyle = call.arguments as String;
      }
      return {
        'style': nativeStyle,
        'foreground': 0xFF123456,
        'background': 0xFFFEDCBA,
      };
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(appIconChannel, null));

  Future<void> open(WidgetTester tester, {double scale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => const AppIconDialog(),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  Future<void> finishApply(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  testWidgets('selection previews first; apply persists and reopens selected', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await tester.tap(find.text('晴蓝'));
    await tester.pumpAndSettle();
    expect(calls.map((c) => c.method), ['get']);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('晴蓝图标'))
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
    await tester.tap(find.text('应用'));
    await finishApply(tester);
    expect(nativeStyle, 'ocean');
    expect(GStorage.setting.get(SettingBoxKey.appIconStyle), 'ocean');
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('晴蓝图标'))
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
    await tester.tap(find.text('恢复默认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用'));
    await finishApply(tester);
    expect(nativeStyle, 'system');
    expect(GStorage.setting.get(SettingBoxKey.appIconStyle), 'system');
    semantics.dispose();
  });

  testWidgets('failed apply keeps dialog and stored choice; retry succeeds', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('青竹'));
    await tester.pumpAndSettle();
    fail = true;
    await tester.tap(find.text('应用'));
    await finishApply(tester);
    expect(find.text('图标切换失败，请重试'), findsOneWidget);
    expect(GStorage.setting.get(SettingBoxKey.appIconStyle), isNull);
    expect(nativeStyle, 'system');
    fail = false;
    await tester.tap(find.text('应用'));
    await finishApply(tester);
    expect(nativeStyle, 'mint');
    expect(find.byType(AppIconDialog), findsNothing);
  });

  testWidgets(
    'narrow screen and large text remain scrollable and cancellable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, scale: 2);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('石墨'));
      await tester.tap(find.text('石墨'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'set'), isEmpty);
    },
  );

  testWidgets(
    'in-flight apply disables duplicate requests and back dismissal',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('樱粉'));
      await tester.pumpAndSettle();
      pending = Completer<void>();
      await tester.tap(find.text('应用'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AppIconDialog), findsOneWidget);
      expect(calls.where((c) => c.method == 'set'), hasLength(1));
      pending!.complete();
      await finishApply(tester);
      expect(nativeStyle, AppIconStyle.rose.name);
      expect(find.byType(AppIconDialog), findsNothing);
    },
  );
}

class _MemorySettings extends Fake implements Box<dynamic> {
  final Map<dynamic, dynamic> _entries = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _entries[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _entries[key] = value;
  }
}
