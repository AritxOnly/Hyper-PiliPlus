import 'package:PiliPlus/common/skeleton/video_card_h.dart';
import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/color_palette.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models/common/home_tab_type.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/models/common/theme/theme_color_type.dart';
import 'package:PiliPlus/models/common/theme/theme_type.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:collection/collection.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class ColorSelectPage extends StatefulWidget {
  const ColorSelectPage({super.key});

  @override
  State<ColorSelectPage> createState() => _ColorSelectPageState();
}

class _ColorSelectPageState extends State<ColorSelectPage> {
  final ctr = Get.put(_ColorSelectController());

  late ThemeData theme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    theme = Theme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = theme.textTheme.titleMedium!;
    final subTitleStyle = theme.textTheme.labelMedium!.copyWith(
      color: theme.colorScheme.outline,
    );
    final padding = MediaQuery.viewPaddingOf(
      context,
    ).copyWith(top: 0, bottom: 0);
    return SimpleScaffold(
      appBar: AppBar(title: const Text('选择应用主题')),
      body: ListView(
        padding: .only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
        ),
        children: [
          ListTile(
            onTap: () async {
              final result = await showDialog<ThemeType>(
                context: context,
                builder: (context) => SelectDialog<ThemeType>(
                  title: '主题模式',
                  value: ctr.themeType.value,
                  values: ThemeType.values.map((e) => (e, e.label)).toList(),
                ),
              );
              if (result != null) {
                try {
                  Get.find<MineController>().themeType.value = result;
                } catch (_) {}
                ctr.themeType.value = result;
                GStorage.setting.put(SettingBoxKey.themeMode, result.index);
                Get.changeThemeMode(ThemeUtils.themeMode = result.toThemeMode);
              }
            },
            leading: const Icon(Icons.flashlight_on_outlined),
            title: Text('主题模式', style: titleStyle),
            subtitle: Obx(
              () => Text(
                '当前模式：${ctr.themeType.value.label}',
                style: subTitleStyle,
              ),
            ),
          ),
          Padding(
            padding: padding + const .all(12),
            child: Obx(
              () => Wrap(
                alignment: .center,
                spacing: 22,
                runSpacing: 18,
                children: colorThemeTypes.mapIndexed(
                  (i, e) {
                    return GestureDetector(
                      behavior: .opaque,
                      onTap: () {
                        ctr.currentColor.value = i;
                        GStorage.setting
                            .put(SettingBoxKey.customColor, i)
                            .whenComplete(Get.updateMyAppTheme);
                      },
                      child: Column(
                        spacing: 3,
                        children: [
                          ColorPalette(
                            colorScheme: e
                                .colorFor(theme.brightness)
                                .asMiuixPresetColorScheme(theme.brightness),
                            selected: ctr.currentColor.value == i,
                          ),
                          Text(
                            e.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: ctr.currentColor.value != i
                                  ? theme.colorScheme.outline
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: const _Preview(),
          ),
        ],
      ),
    );
  }
}

class _ColorSelectController extends GetxController {
  final RxInt currentColor = Pref.customColor.obs;
  final Rx<ThemeType> themeType = Pref.themeType.obs;
}

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    const cardH = SizedBox(
      height: 110,
      child: VideoCardHSkeleton(skeleton: false),
    );
    const cardV = Expanded(
      child: SizedBox(
        height: 200,
        child: Card(child: VideoCardVSkeleton(skeleton: false)),
      ),
    );
    final child = Column(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const .fromLTRB(14, 8, 14, 0),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const .all(.circular(25)),
                      color: colorScheme.onSecondaryContainer.withValues(
                        alpha: 0.05,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        Icon(
                          Icons.search_outlined,
                          color: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  padding: .zero,
                  backgroundColor: colorScheme.onInverseSurface,
                ),
                onPressed: () {},
                icon: Icon(
                  Icons.person_rounded,
                  size: 22,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        DefaultTabController(
          initialIndex: 1,
          length: HomeTabType.values.length,
          child: SizedBox(
            height: 42,
            child: TabBar(
              dividerHeight: 0,
              tabs: HomeTabType.values.map((e) => Tab(text: e.label)).toList(),
            ),
          ),
        ),
        const Padding(
          padding: .symmetric(horizontal: Style.safeSpace, vertical: 5),
          child: Row(
            spacing: 8,
            children: [cardV, cardV],
          ),
        ),
        cardH,
        cardH,
        const SizedBox(height: 5),
        NavigationBar(
          destinations: NavigationBarType.values
              .map(
                (item) => NavigationDestination(
                  icon: item.icon,
                  label: item.label,
                ),
              )
              .toList(),
        ),
      ],
    );

    return ExcludeFocus(
      child: IgnorePointer(
        child: Center(
          child: ConstrainedBox(
            constraints: const .new(maxWidth: 380),
            child: child,
          ),
        ),
      ),
    );
  }
}
