# Hyper-PiliPlus Android 签名发布

## 版本规则

`pubspec.yaml` 保持上游的三段语义版本（现在是 `2.1.3+1`），不要改成四段，以免破坏 Pub / 其他平台构建。
`tool/release.json` 记录对应的 `upstreamVersion` 和本分支 `revision`：

- 首次：`2.1.3.0`；后续：`2.1.3.1`、`2.1.3.2`。
- 升级上游到 `2.1.4` 时，同时修改 `pubspec.yaml` 与 `upstreamVersion`，并将 `revision` 重置为 `0`，生成 `2.1.4.0`。
- Android `versionName` 与应用内版本均为四段，不再附加提交哈希；哈希单独保存到 `pili.hash`。
- `versionCode = major × 10000000 + minor × 100000 + patch × 100 + revision`；首次为 `20100300`，高于此前本地包的 `5348`。
- 范围：major 0–199，minor 0–99，patch 0–999，revision 0–99。脚本拒绝超界，以保证升级顺序和 Android 整数限制。
- Release 标签严格为 `v2.1.3.0`。正式发布后不可覆盖同一标签；发布修复版必须递增 revision。

## 配置签名 Secrets

仓库：`AritxOnly/Hyper-PiliPlus` → Settings → Secrets and variables → Actions。
按 GitHub 的 [Secrets 文档](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets) 添加：

| 名称 | 内容 |
| --- | --- |
| `SIGN_KEYSTORE_BASE64` | 已有 Release keystore 的 Base64 编码 |
| `KEYSTORE_PASSWORD` | keystore 密码 |
| `KEY_ALIAS` | 签名密钥别名 |
| `KEY_PASSWORD` | 密钥密码 |

**必须使用此前本机 Release 的同一把签名密钥**，否则无法覆盖安装并保留现有应用数据。不要重新生成密钥替代旧密钥。
Base64 不是加密；不要将编码内容、密码、`key.properties` 或 keystore 提交到 Git。
工作流仅在临时目录解码 keystore，密码由环境变量传给 Gradle，构建结束清理临时文件。
缺少任意签名项会失败，不会以 debug 签名发布。APK、版本元数据及校验和以外的文件不会上传。
只在受信任的分支执行签名构建，不要将 Secrets 暴露给外部 PR 的代码。

## 手动构建与发布

1. 将提交推送到 GitHub 默认分支，确认上述 Secrets 已配置。
2. Actions → **Hyper-PiliPlus Android Release** → Run workflow。
3. `publish` 默认关闭：仅生成三种 ABI 的签名 APK，下载 `android-signed-2.1.3.0` Artifact。
4. 勾选 `publish`：构建和签名验证成功后创建 `v2.1.3.0` 正式 Release，附 APK、SHA256SUMS 和 release-metadata.json。
5. 老的 **Build** 工作流中的 Android 选项也复用新流程。若填写 tag，必须与配置生成的标签完全一致；它的其他平台仍沿用上游流程与三段版本。

应用通过本仓库的 `/releases/latest` 接口检查更新，按四段数字而不是时间比较；同版本重编译不会反复提示。
草稿、预发布和三段旧标签不会被当成新的正式 flavor 版本。只有上传 Artifact、不发布 Release 时，不会触发应用更新提示。
详情参见 GitHub 的 [Release API](https://docs.github.com/en/rest/releases/releases#get-the-latest-release)。

## 构建环境

流程基于 [PiliPlus 上游 Android 工作流](https://github.com/bggRGjQaUbCoE/PiliPlus/blob/main/.github/workflows/build.yml) 的迁出、Java、SDK 补丁、签名、分 ABI 构建、上传与发布步骤。
为保留本分支功能，使用固定 Flutter 提交和 `tool/flutter-sdk.patch`，再按上游顺序应用 `lib/scripts/material/` 的 Android 包补丁。
包目录从 `.dart_tool/package_config.json` 读取，不猜测缓存目录。签名构建要求显式启用 `requireReleaseSigning`。

Android SDK 平台的安装标识为 `platforms;android-37.0`（包含 `.0`），不是 `platforms;android-37`；Gradle 的 `compileSdk` / `targetSdk` 仍填写整数 `37`。工作流安装后会检查对应 `android.jar` 是否存在。

Flutter 按固定 SHA 检出后还必须获取官方 `3.47.2` 标签：仅有提交的浅克隆可能被 Flutter 识别成 `0.0.0-unknown`。工作流显式获取并校验标签对应的提交，单独执行 `flutter --version` 完成首次初始化，再读取 Flutter 自动生成的 `bin/cache/flutter.version.json`，核对版本与 `.fvmrc`、提交与 SDK HEAD 一致。不要直接将首次启动的 stdout 管道交给 JSON 解析器：其中可能混入工具自身的依赖解析日志。此过程不修改或伪造 SDK 版本。

首次云构建使用仓库 `pubspec.lock`（`--enforce-lockfile`）。它与旧本机缓存存在已知差异（见 [Flutter 环境说明](flutter-environment.md)），因此本机成功不能代替首次云运行验证；如锁文件/补丁不兼容，流程会停止，不会静默升级依赖或发布。

本机使用已有签名配置构建同规则版本：

```sh
python3 scripts/release_metadata.py
./scripts/flutterw build apk --release --split-per-abi --no-pub \
  --build-name=2.1.3.0 --build-number=20100300 \
  --dart-define-from-file=pili_release.json \
  --android-project-arg requireReleaseSigning=true
```

后续版本参数以元数据脚本输出为准。本流程不会自动替你推送提交、上传 Secrets 或启动远端构建。
