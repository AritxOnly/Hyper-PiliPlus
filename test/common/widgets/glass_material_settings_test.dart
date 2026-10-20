import 'dart:io';

import 'package:PiliPlus/models/common/glass_material_tuning.dart';
import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/setting/common_setting.dart';
import 'package:PiliPlus/pages/setting/widgets/glass_material_slider_dialog.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final settings = _MemorySettings();
  late Directory appSupportDirectory;
  setUpAll(() {
    GStorage.setting = settings;
    // Linux style settings read the SSD marker beneath the application support
    // directory. Supply the same path initialization as app startup on every host.
    appSupportDirectory = Directory.systemTemp.createTempSync(
      'glass-settings-',
    );
    appSupportDirPath = appSupportDirectory.path;
  });
  tearDownAll(() => appSupportDirectory.deleteSync(recursive: true));
  setUp(() {
    settings.entries.clear();
    settings.entries[SettingBoxKey.horizontalScreen] = false;
  });

  test(
    'missing and corrupt preferences retain Deadliner default and bounds',
    () {
      expect(Pref.glassBlurRadius, 84);
      for (final value in [null, 'bad', double.nan, double.infinity]) {
        expect(GlassMaterialTuning.normalize(value), 84);
      }
      expect(GlassMaterialTuning.normalize(-1), 16);
      expect(GlassMaterialTuning.normalize(999), 168);
      settings.entries[SettingBoxKey.glassBlurRadius] = 120;
      expect(Pref.glassBlurRadius, 120);
    },
  );

  testWidgets('drag, cancel, save and reset share the original setting', (
    tester,
  ) async {
    Future<void> openPage(SettingType type) async {
      await tester.pumpWidget(
        GetMaterialApp(
          key: UniqueKey(),
          home: CommonSetting(key: UniqueKey(), settingType: type),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Settings page must mount before scrolling',
      );
      await tester.scrollUntilVisible(
        find.text('柔光玻璃通透程度'),
        150,
        continuous: true,
        duration: const Duration(milliseconds: 200),
      );
      await tester.tap(find.text('柔光玻璃通透程度'));
      await tester.pumpAndSettle();
    }

    await openPage(.featureSetting);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 84);
    await tester.drag(find.byType(Slider), const Offset(90, 0));
    await tester.pumpAndSettle();
    final changed = tester.widget<Slider>(find.byType(Slider)).value;
    expect(changed, greaterThan(84));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(Pref.glassBlurRadius, 84);

    await tester.tap(find.text('柔光玻璃通透程度'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(60, 0));
    await tester.pumpAndSettle();
    final saved = tester.widget<Slider>(find.byType(Slider)).value;
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(Pref.glassBlurRadius, saved);

    await openPage(.styleSetting);
    expect(tester.widget<Slider>(find.byType(Slider)).value, saved);
    await tester.tap(find.text('恢复默认'));
    await tester.pump();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 84);
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(Pref.glassBlurRadius, 84);
  });

  testWidgets('narrow dialog supports large text and RTL', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        ),
        home: const Scaffold(body: GlassMaterialSliderDialog(value: 168)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('默认 84'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).max, 168);
  });
}

class _MemorySettings extends Fake implements Box<dynamic> {
  final Map<dynamic, dynamic> entries = {};
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      entries[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async => entries[key] = value;
}
