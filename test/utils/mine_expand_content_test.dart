import 'dart:io';
import 'dart:async';

import 'package:PiliPlus/models/common/mine_expand_content.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/history/data.dart';
import 'package:PiliPlus/models_new/later/data.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/services/account_service.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/storage_key.dart';
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
    'watch later persists without changing legacy selection indices',
    () async {
      for (final content in MineExpandContent.values) {
        Pref.mineExpandContent = content;
        await GStorage.setting.flush();
        expect(Pref.mineExpandContent, content);
      }
      await GStorage.setting.put(SettingBoxKey.mineExpandContent, 0);
      expect(Pref.mineExpandContent, MineExpandContent.favorite);
      await GStorage.setting.put(SettingBoxKey.mineExpandContent, 1);
      expect(Pref.mineExpandContent, MineExpandContent.history);
      expect(MineExpandContent.later.route, '/later');
      expect(MineExpandContent.later.title, '稍后再看');
    },
  );

  test('switching to watch later drops stale history and refreshes the selected content', () async {
    Get.put<AccountService>(AccountService());
    final controller = _QueuedMineController();
    final history = controller.queryData();
    controller.onExpandContentChanged(MineExpandContent.later);
    expect(controller.list.map((item) => item.title), [
      '离线缓存',
      '我的收藏',
      '观看记录',
      '我的订阅',
    ]);
    controller.pending[MineExpandContent.history]!.complete(
      Success(HistoryData()),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.requests, [
      MineExpandContent.history,
      MineExpandContent.later,
    ]);
    expect(controller.loadingState.value, isA<Loading>());
    final later = LaterData(list: []);
    controller.pending[MineExpandContent.later]!.complete(Success(later));
    await history;
    expect(
      controller.loadingState.value,
      isA<Success<Object>>().having(
        (state) => state.response,
        'selected response',
        same(later),
      ),
    );
    controller.onDelete();
    Get.reset();
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

class _QueuedMineController extends MineController {
  final requests = <MineExpandContent>[];
  final pending = <MineExpandContent, Completer<LoadingState<Object>>>{};

  @override
  Future<LoadingState<Object>> getExpandContent(MineExpandContent content) {
    requests.add(content);
    return (pending[content] = Completer<LoadingState<Object>>()).future;
  }

  @override
  Iterable<MineRefreshMixin> tabCtr() => [];
}
