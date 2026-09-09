# 固定 Flutter 构建环境

本项目已验证的 Android 构建环境是 **Flutter 3.47.2 stable / Dart 3.13.2**。

- Flutter 提交：`d3b14c876900e553bc736ca19295fc09e3853e8e`
- Engine 提交：`a804b261645ef8c13eb3d5c44a5c2fb0340c5539`
- `.fvmrc` 固定版本。仓库包含 `pubspec.lock`，但它与本机此前构建使用的解析结果存在历史差异，见下文。
- `tool/flutter-sdk.patch` 保存已用于 Release 的 SDK 完整补丁（35 个文件）。补丁 SHA-256 为 `7b5dc6ad15e1e2d2d6218b050bfccb62ba7abd2e6d0be25d008b39284c9d4299`。

这不是原版 SDK：项目依赖补丁暴露的 API。仅安装同版本原版 Flutter 不足以恢复环境。不要在已打补丁的 SDK 上重复运行 `lib/scripts/patch.ps1`；该上游脚本仍供原有 CI 使用，本快照固定的是本地已验证环境。

## 当前电脑

持久 SDK 位于 `/Users/aritxonly/development/hyper-piliplus-flutter-3.47.2`，项目通过被 Git 忽略的 `.fvm/flutter_sdk` 链接访问它。终端全局 Flutter 保持原样，避免影响其他工程。VS Code 使用项目链接；Android Studio 可把 Flutter SDK path 设为项目的 `.fvm/flutter_sdk`。

项目命令统一从仓库根目录执行：

```sh
./scripts/flutterw --check-sdk
./scripts/flutterw --version
./scripts/flutterw analyze --no-pub lib
./scripts/flutterw test --no-pub
./scripts/flutterw build apk --release --split-per-abi --no-pub
```

包装器每次检查 SDK 提交和全部已跟踪补丁，环境不匹配时直接报错，不会使用 PATH 中的其他 Flutter。本机保留原有依赖解析结果，使用 `--no-pub`；发布版本参数和签名仍按项目发布流程提供。

## 已发现的依赖差异

`dynamic_color` 的锁文件曾误记为 `2.1.0`，与 `flutter_miuix 1.1.1` 的 `^1.9.0` 约束冲突。现已将该项及归档 SHA-256 校正为本机 Release 实际使用的 `1.9.0`；CI 继续启用 `--enforce-lockfile`，不通过自动升级掩盖不一致。

此前 Release 实际使用的 `media_kit` Git 提交为 `08b7b9410968fa39ae2fc814d57f9f889079afc9`，仓库锁文件记录的是 `73771ec38176be2d984a3049c28177bce23b54a0`。严格离线恢复锁文件会尝试获取本机缺失的 Git 仓库，因此本次没有重解析或升级依赖。

`tool/dependencies-local-snapshot.json` 记录了当前全部包的解析位置（SDK、缓存目录均用占位符），用于后续核对实际版本。它是诊断快照，不替代 `pubspec.lock`。SDK 迁移已完成；全新电脑要复现之前 Release 的全部依赖，还需要单独校准锁文件。恢复仓库锁文件可使用 `./scripts/flutterw pub get --enforce-lockfile`，但不能据此认为使用的就是此前本机依赖。

## 在其他电脑恢复

1. 安装 Flutter 3.47.2 到本项目独占的持久目录（可用 FVM 安装，但不要修改供其他项目共用的 SDK）。确认 `git rev-parse HEAD` 与上述提交一致，且 `git status --porcelain` 为空。
2. 在干净 SDK 上应用本仓库的 `tool/flutter-sdk.patch`：

   ```sh
   git -C /absolute/path/to/flutter apply --check /absolute/path/to/project/tool/flutter-sdk.patch
   git -C /absolute/path/to/flutter apply /absolute/path/to/project/tool/flutter-sdk.patch
   ```

3. 在项目根目录创建本机链接：`mkdir -p .fvm`，然后 `ln -s /absolute/path/to/flutter .fvm/flutter_sdk`。已有链接时先确认它的目标，勿覆盖实际 SDK 目录。
4. 执行 `./scripts/flutterw --check-sdk` 和 `./scripts/flutterw pub get --enforce-lockfile`，再运行测试。Android SDK、JDK 和签名文件仍需在本机配置；本次只固定 Flutter/Dart 与已有依赖锁，不承诺所有平台构建字节完全相同。

升级 Flutter 时应单独评审版本、SDK 补丁、包装器内的提交/校验和与依赖锁，并通过测试和 Release 构建后再切换；不要直接运行 `flutter upgrade` 或 `pub upgrade`。
