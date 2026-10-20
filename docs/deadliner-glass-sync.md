# Deadliner 柔光玻璃同步

来源：本机 Android Deadliner `9119af22`（2026-10-18）。材质、导航与反馈源码位于
`app/src/main/java/com/aritxonly/deadliner/`，本项目副本位于 Android Kotlin 同名包。
双方使用 MIUIX `0.9.4-rc01`；本项目保留 Compose 编译器 `2.3.20`。

本次同步包含玻璃光学边缘、三倍模糊核采样留白、主题阴影及默认材质参数、导航按压反馈。
官方玻璃实验分支所需的完整依赖保存在 `android/third_party/miuix-glass`，版权和来源说明随附；
默认仍使用 Deadliner 的自有柔光玻璃，未开启实验开关。

主页底部背景来自 `ImmersiveMiuixCompactNavigationScaffold.kt` 的
`FloatingNavigationEdgeMask`，沿用 `EdgeFade.kt` 的透明度遮罩。
覆盖高度为底栏 56dp + 底部间距 4dp + 渐隐延伸 32dp + 系统导航栏 + 用户设置的抬升。
渐变使用 MIUIX surface，独立绘制在底栏后方，不进入 Flutter 采样源，不接收点击。

本地适配：

- 保留 Flutter 路由和未读角标、PixelCopy 帧通知、弹层遮挡与采样冻结。
- 将 Deadliner 的抬升 CompositionLocal 参数化，由已有 Flutter/原生桥接提供。
- 去掉材质调节工具中依赖 Deadliner 业务配置对象的两个未使用方法。
- 采样裁剪额外留白增至 128dp，覆盖新版模糊核和折射位移；仍保留 20% 下采样。
- 仅引用所需公共反馈与顶栏辅助组件，不导入 Deadliner 业务页面。

采样坐标修复：PixelCopy 快照保留裁剪区域在窗口中的真实起点，
Compose 根据该起点与当前底栏的坐标差对齐背景；屏幕边缘裁剪不再被当作对称扩边居中。
底栏抬升或进入动画期间也以当前底栏位置计算偏移。仍使用普通 APK 可用的 PixelCopy，
不依赖 HyperModifier/LSPosed 的隐藏捕获接口，也不改变 Deadliner 的光学材质配方。
`test/scripts/backdrop_geometry_test.py` 在 JVM 上执行生产坐标公式，覆盖边缘裁剪、
Surface 窗口偏移、底栏移动和奇数像素尺寸。

上游 PiliPlus 同步到 `0d83df96f`。Flutter 继续固定项目补丁版 3.47.4；
新增双击时间戳通过公开 pointer router 观察，未改动 SDK。
底部 Sheet 使用现有 SDK/Material 非泛型 State，并收窄 widget getter。
MIUIX 配色和默认 350 字重保留；我的页在未配置卡片列表时保留原有收藏/最近播放模式，
配置后使用上游多卡片列表。

依赖锁文件使用 pub.dev，保留本机原有 `flutter_miuix 1.2.0` 和其依赖的
`dynamic_color 1.9.0`，不升级 SDK 或全量升级依赖。严格恢复时使用
`PUB_HOSTED_URL=https://pub.dev ./scripts/flutterw pub get --enforce-lockfile`。
