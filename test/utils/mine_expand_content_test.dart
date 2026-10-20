import 'dart:io';
import 'dart:async';

import 'package:PiliPlus/models/common/mine_expand_content.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:get/get.dart';

void main() {
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('piliplus-mine-test-');
    Hive.init(directory.path);
    GStorage.setting = await Hive.openBox('setting');
    GStorage.userInfo = await Hive.openBox('userInfo');
  });

  setUp(() => GStorage.setting.clear());

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('mine expansion defaults to recent history', () {
    expect(Pref.mineExpandContent, MineExpandContent.history);
  });

  test('floating glass navigation defaults to enabled', () {
    expect(Pref.floatingNavBar, isTrue);
  });

  test('mine expansion selection is persisted', () async {
    Pref.mineExpandContent = MineExpandContent.favorite;
    await GStorage.setting.flush();
    expect(Pref.mineExpandContent, MineExpandContent.favorite);
  });

  test(
    'legacy mine refresh stays pending until the expanded card finishes',
    () async {
      Get.put<AccountService>(AccountService()).isLogin.value = true;
      final controller = _PendingMineController();
      var completed = false;
      final refresh = controller.onRefresh(isManual: false).then((_) {
        completed = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      controller.pending.complete();
      await refresh;
      expect(completed, isTrue);
      controller.onDelete();
      Get.reset();
    },
  );
}

class _PendingMineController extends MineController {
  final pending = Completer<void>();

  @override
  Future<void> queryData([bool isRefresh = true]) => pending.future;

  @override
  Iterable<MineRefreshMixin> tabCtr() => [];
}
