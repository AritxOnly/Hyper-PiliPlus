import 'dart:io';

import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('piliplus-font-test-');
    Hive.init(directory.path);
    GStorage.setting = await Hive.openBox('setting');
  });
  setUp(() => GStorage.setting.clear());
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test('default weight is between light and regular', () {
    expect(Pref.appFontWeight.value, 350);
  });
  test('old explicitly selected weight is preserved', () async {
    await GStorage.setting.put(SettingBoxKey.appFontWeightV2, 2);
    expect(Pref.appFontWeight.value, 300);
  });
  test('precise weight overrides legacy index without rounding', () async {
    await GStorage.setting.put(SettingBoxKey.appFontWeightV2, 2);
    await GStorage.setting.put(SettingBoxKey.appFontWeightValue, 350);
    expect(Pref.appFontWeight.value, 350);
    await GStorage.setting.put(SettingBoxKey.appFontWeightValue, 450);
    expect(Pref.appFontWeight.value, 450);
  });
}
