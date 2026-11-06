import 'dart:io';

import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('sidebar-collapse-test-');
    Hive.init(directory.path);
    GStorage.setting = await Hive.openBox('setting');
    GStorage.video = await Hive.openBox('video');
    GStorage.localCache = await Hive.openBox('localCache');
    GStorage.userInfo = await Hive.openBox('userInfo');
  });
  setUp(() async {
    await GStorage.setting.clear();
    Get.put<AccountService>(AccountService());
  });
  tearDown(Get.reset);
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'sidebar collapse persists without changing the selected destination',
    () async {
      final controller = MainController();
      controller.selectedIndex.value = 1;
      expect(controller.hideSideBarLabel.value, isFalse);
      controller.toggleSideBar();
      await GStorage.setting.flush();
      expect(controller.hideSideBarLabel.value, isTrue);
      expect(Pref.hideSideBarLabel, isTrue);
      expect(controller.selectedIndex.value, 1);
      controller.toggleSideBar();
      await GStorage.setting.flush();
      expect(Pref.hideSideBarLabel, isFalse);
      expect(controller.selectedIndex.value, 1);
    },
  );
}
