# 固定 Flutter 构建环境

本项目已验证的 Android 构建环境是 **Flutter 3.47.4 stable / Dart 3.13.3**。

- Flutter 提交：`9584c6713b324636289d067944a46fd6b49df14b`
- Engine 提交：`06a2e2a110089dff50fe635cffd2a61e1b24fbcd`
- `.fvmrc` 固定版本。仓库包含 `pubspec.lock`，但它与本机此前构建使用的解析结果存在历史差异，见下文。
- `tool/flutter-sdk.patch` 保存已用于 Release 的 SDK 完整补丁（35 个文件）。补丁 SHA-256 为 `7b5dc6ad15e1e2d2d6218b050bfccb62ba7abd2e6d0be25d008b39284c9d4299`。

这不是原版 SDK：项目依赖补丁暴露的 API。仅安装同版本原版 Flutter 不足以恢复环境。不要在已打补丁的 SDK 上重复运行 `lib/scripts/patch.ps1`；该上游脚本仍供原有 CI 使用，本快照固定的是本地已验证环境。

## 当前电脑

持久 SDK 位于项目专用的 `.fvm/flutter_sdk_3.47.4`，项目通过被 Git 忽略的 `.fvm/flutter_sdk` 链接访问它。终端全局 Flutter 保持原样，避免影响其他工程。VS Code 使用项目链接；Android Studio 可把 Flutter SDK path 设为项目的 `.fvm/flutter_sdk`。

项目命令统一从仓库根目录执行：

```sh
./scripts/flutterw --check-sdk
./scripts/flutterw --version
./scripts/flutterw analyze --no-pub lib
./scripts/flutterw test --no-pub
./scripts/flutterw build apk --release --split-per-abi --no-pub
```

包装器每次检查 SDK 提交和全部已跟踪补丁，环境不匹配时直接报错，不会使用 PATH 中的其他 Flutter。本机保留原有依赖解析结果，使用 `--no-pub`；发布版本参数和签名仍按项目发布流程提供。

## 本次上游同步后的依赖

上游同步到 `0d83df96f`，应用版本为 `2.1.6`。保留本项目独占的补丁版 Flutter 3.47.4，
未自动切换到上游 3.47.7；手势时间戳使用公开 pointer router 适配。

锁文件对齐此次上游依赖，并保留当前 MIUIX 使用的 `flutter_miuix 1.2.0`、
`dynamic_color 1.9.0` 和 `cupertino_icons 1.0.9`。这三个包的版本和官方归档哈希已核对。
锁文件统一使用 pub.dev；若本机默认使用其他镜像，严格恢复时显式指定：

```sh
PUB_HOSTED_URL=https://pub.dev ./scripts/flutterw pub get --enforce-lockfile
```

本次已先在独立临时项目严格验证锁文件，再恢复当前项目依赖。
`material_ui` 更新为上游锁定的 `1.6.0`，使用仓库 `scripts/prepare_android_ci.py`
恢复 Android 包补丁。SDK 补丁无需重复应用。

当前实际解析的 `media_kit` Git 提交为 `73771ec38176be2d984a3049c28177bce23b54a0`，
`media_kit_video` 为 `85f0a69ea66b100882b27a3375c72e5155375343`，均与锁文件一致。
`tool/dependencies-local-snapshot.json` 是此前本地环境的历史快照，不代表此次解析结果；
实际位置以 `.dart_tool/package_config.json` 为准。

## Ubuntu 上的 Flutter 测试

即使最终构建 Android APK，`flutter test` 也会为 Ubuntu 测试宿主编译
`cnativeapi` 原生资产。Android Release 工作流会先安装 `clang`、`pkg-config`、
`libgtk-3-dev`、`libx11-dev` 和 `libxi-dev`，并用
`pkg-config --cflags --libs gtk+-3.0 x11 xi` 检查头文件与链接库是否可用。
只安装 Android SDK/NDK 不能满足此测试宿主依赖；不要通过跳过测试绕开错误。

## 在其他电脑恢复

1. 安装 Flutter 3.47.4 到本项目独占的持久目录（可用 FVM 安装，但不要修改供其他项目共用的 SDK）。确认 `git rev-parse HEAD` 与上述提交一致，且 `git status --porcelain` 为空。
2. 在干净 SDK 上应用本仓库的 `tool/flutter-sdk.patch`：

   ```sh
   git -C /absolute/path/to/flutter apply --check /absolute/path/to/project/tool/flutter-sdk.patch
   git -C /absolute/path/to/flutter apply /absolute/path/to/project/tool/flutter-sdk.patch
   ```

3. 在项目根目录创建本机链接：`mkdir -p .fvm`，然后 `ln -s /absolute/path/to/flutter .fvm/flutter_sdk`。已有链接时先确认它的目标，勿覆盖实际 SDK 目录。
4. 执行 `./scripts/flutterw --check-sdk` 和 `PUB_HOSTED_URL=https://pub.dev ./scripts/flutterw pub get --enforce-lockfile`，再运行测试。Android SDK、JDK 和签名文件仍需在本机配置；本次只固定 Flutter/Dart 与已有依赖锁，不承诺所有平台构建字节完全相同。

升级 Flutter 时应单独评审版本、SDK 补丁、包装器内的提交/校验和与依赖锁，并通过测试和 Release 构建后再切换；不要直接运行 `flutter upgrade` 或 `pub upgrade`。
