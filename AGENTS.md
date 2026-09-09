# Hyper-PiliPlus 开发规范

本文件适用于整个仓库。开始任务先阅读本文件，再根据修改范围阅读相关代码与文档；用户本轮明确要求优先于本文件中的默认工作方式。

## 项目与工作边界

- 本项目是 PiliPlus 的定制分支，主要使用 Flutter/Dart，Android 侧包含 Kotlin/Compose 原生柔光玻璃底栏及交互桥接。
- `origin`：`AritxOnly/Hyper-PiliPlus`；`upstream`：`bggRGjQaUbCoE/PiliPlus`。操作前以 `git remote -v` 核实，禁止误推到上游。
- 修改前运行 `git status --short`、查看相关 diff。保留用户和并行任务的修改，不回滚、不覆盖、不顺手格式化无关文件。
- 合并上游时尽量保留本分支已有功能。逐处理解冲突，不整文件选用上游版本；遇到无法兼容的行为差异向用户说明。
- 排查、解释和审查不自动扩展为大范围重构。提交、推送、触发 Actions、发布 Release 是不同操作，按用户授权执行；不要把一次推送视为永久自动发布授权。
- 禁止擅自 `reset --hard`、强推、删除工作区或重建签名密钥。不要自动升级 Flutter、插件和依赖来掩盖错误。
- 使用中文沟通，说明实际改动、验证结果和未验证项。构建未完成或测试未执行时，不声称通过。

## 代码入口与修改原则

- 页面：`lib/pages/`；通用组件：`lib/common/widgets/`；播放器：`lib/plugin/pl_player/`。
- Android 原生代码：`android/app/src/main/`；平台调用及采样通知：`lib/utils/android/`。
- 共享转场：`lib/common/widgets/video_card/video_card_transition.dart`。
- 更新检测：`lib/utils/update.dart`、`lib/utils/release_version.dart`；仓库地址集中在 `lib/common/constants.dart`。
- 版本元数据：`scripts/release_metadata.py`、`tool/release.json`；签名 CI：`.github/workflows/android-release.yml`。
- 优先使用 `rg` 查找，修改本次涉及的最小范围。使用 `apply_patch` 编辑源码；格式化只指定本次涉及的 Dart 文件。
- 遵循周边代码的 GetX 生命周期、控制器所有权和路由约定。保留原有点击、长按、拖动、弹幕、倍速、清晰度等功能，不因布局调整丢失交互。
- 不直接编辑生成代码、Pub 缓存或 SDK 来临时消除编译错误。补丁必须有仓库内来源，并同步恢复流程和验证。

## Flutter 与依赖环境

详细流程见 [Flutter 环境说明](docs/flutter-environment.md)。当前固定环境为 Flutter **3.47.2** / Dart **3.13.2**，不是未修改的官方 SDK。

- Flutter 提交：`d3b14c876900e553bc736ca19295fc09e3853e8e`。
- SDK 补丁：`tool/flutter-sdk.patch`；版本和补丁校验由 `scripts/flutterw` 执行。
- Flutter 命令统一使用 `./scripts/flutterw`，禁止回退到 PATH 中的全局 Flutter。
- Dart 命令使用 `.fvm/flutter_sdk/bin/dart`；包装器不支持 `./scripts/flutterw dart ...`。
- 开始构建前执行 `./scripts/flutterw --check-sdk`。不要修改供其他工程共用的 SDK。
- 已配置的本机工作区默认使用 `--no-pub`，不无故改变 `.dart_tool/package_config.json` 的解析结果。
- 全新环境和 CI 使用 `./scripts/flutterw pub get --enforce-lockfile`。实际包路径从 `.dart_tool/package_config.json` 获取，不猜测缓存目录或选择缓存中“最新”的版本。
- 锁文件冲突要核对依赖约束、版本和归档 SHA-256，只修正必要项；禁止通过删除锁文件、取消严格检查或全量 `pub upgrade` 绕过错误。
- 本机历史解析结果与仓库锁文件可能不同，尤其是 `media_kit` Git 提交。验证 CI 依赖时优先使用独立临时工作目录，避免破坏当前已验证环境。临时目录执行 SDK 的绝对路径命令前，先在原工作区验证 SDK；包装器会切回仓库根目录，不适合直接用于临时项目。
- SDK 补丁和 `material_ui` 包补丁是两层。新 CI 先恢复完整 SDK 补丁，再运行 `scripts/prepare_android_ci.py`；不要在已打补丁的本机缓存或 SDK 上重复应用。

## UI 与已有功能保护

- 背景色使用场景对应的 `ColorScheme`，不要硬编码“接近”的颜色。动态详情正文及本轮统一的评论排序栏使用 `surfaceContainerLowest`；不要误改为 `surface`、`surfaceContainerLow`，也不要全局替换所有 surface 层级。
- 转场的卡片色、目标页面色跟随实际场景。修改正文背景时同时检查 Hero 目标色，避免动画结束时跳色。
- 保留共享转场的快速返回、预测返回和取消手势行为；不得重复播放退出动画、闪出空容器或过早初始化播放器造成卡顿。
- 动画涉及全屏透明度、模糊或实时截图时评估性能。当前方案采用背景压暗；没有新需求不要重新引入昂贵的实时背景模糊。
- 原生底栏采样需响应刷新后的 Flutter 帧；转场冻结、恢复、页面不可见及弹层遮挡必须成对处理，避免刷新不更新或后台持续采样。
- Sheet、Toast、长按菜单不能被原生底栏遮挡；Flutter 弹层应保持现有遮挡管理与回退机制。
- 复制内容弹窗保持 Flutter；文本多选后的 Android 操作工具栏使用已有原生桥接，不把整个复制弹窗改回原生。
- 默认字重为 350；不要擅自改为 300 或 400，也不要覆盖用户明确选择的字重。
- 播放器布局需覆盖窄屏、横屏和大字体。文字在完整触摸区域内居中，不以缩小点击区域换取对齐。
- 动态评论返回要保留正文和评论两层滚动进度。`NestedScrollView` 不能简单对内外控制器分别 `jumpTo`；遵循已有 `ScrollPositionBookmark` 的协调恢复逻辑。

## 测试与交付要求

**功能、UI、动画或 Android 原生实现改动，默认需要测试并生成签名 Release APK，交给用户自行测试。** 用户明确要求仅改代码、暂不打包时例外。纯文档修改不需要 APK；仅 CI 配置修改以流程校验及对应故障复现为主，不能用本机打包成功冒充云端运行成功。

常用检查（从仓库根目录运行，路径替换为实际修改文件）：

```sh
./scripts/flutterw --check-sdk
.fvm/flutter_sdk/bin/dart format lib/path/to/changed_file.dart test/path/to/changed_test.dart
./scripts/flutterw analyze --no-pub lib/path/to/changed_file.dart test/path/to/changed_test.dart
./scripts/flutterw test --no-pub
python3 -m unittest discover -s test/scripts -p '*_test.py'
git diff --check
```

- 修复行为缺陷时补充针对性回归测试，优先测试真实布局、点击区域、状态恢复及生命周期，而不只测试文字存在。
- 重点回归包括转场途中快速返回/取消、滚动位置恢复、刷新后底栏重采样、弹层遮挡释放，以及播放器不同宽度和文字缩放。
- 当前 `test/` 下已有 Flutter 测试，版本脚本测试位于 `test/scripts/`。测试数量会增长，报告本次实际数量，不把历史数量写死为验收要求。
- `.gitignore` 包含 `test*`：新增测试可能被忽略。提交时核对 `git status`，必要时对具体测试文件执行 `git add -f`；不要强制加入整个目录，以免包含 `__pycache__` 等产物。
- Actions 修改可运行：`go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7 -shellcheck= -pyflakes= .github/workflows/android-release.yml .github/workflows/build.yml`。这只校验配置，不证明远端构建通过。
- 缺少签名、SDK、网络或其他条件时，明确说明失败阶段和已完成检查，不以 debug APK 冒充 Release。

## 本机签名打包方式

详细规则见 [Android 发布说明](docs/android-release.md)。本机使用既有 `android/key.properties` 和同一份签名文件，CI 使用 Secrets。

先确认最终源码状态，再生成元数据。若任务要求提交，尽量在源码提交后生成元数据，避免 `pili.hash` 落后于本次源码；包含未提交更改的包必须在交付时明确说明。

以下命令从配置自动读取版本，不手填历史版本号，不再用 Git 提交数量作为 Android versionCode：

```sh
set -euo pipefail
python3 scripts/release_metadata.py
release_version_name="$(python3 -c 'import json; print(json.load(open("pili_release.json"))["pili.name"])')"
release_version_code="$(python3 -c 'import json; print(json.load(open("pili_release.json"))["pili.code"])')"
./scripts/flutterw build apk --release --split-per-abi --no-pub \
  --build-name="$release_version_name" \
  --build-number="$release_version_code" \
  --dart-define-from-file=pili_release.json \
  --android-project-arg requireReleaseSigning=true
```

输出位于 `build/app/outputs/flutter-apk/`：

- `app-arm64-v8a-release.apk`：默认交付给用户的安装包。
- `app-armeabi-v7a-release.apk`、`app-x86_64-release.apk`：其他 ABI。

构建结束后必须检查进程成功退出、产物存在、签名及包内版本。Android SDK 路径优先读取 `ANDROID_HOME` / `ANDROID_SDK_ROOT`，否则从本机 `android/local.properties` 的 `sdk.dir` 获取，不将个人绝对路径写入工程配置。

```sh
set -euo pipefail
android_sdk_dir="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$android_sdk_dir" ]; then
  android_sdk_dir="$(awk -F= '$1 == "sdk.dir" { print substr($0, index($0, "=") + 1); exit }' android/local.properties | tr -d '\r')"
fi
test -x "$android_sdk_dir/build-tools/36.0.0/apksigner"
for abi in arm64-v8a armeabi-v7a x86_64; do
  "$android_sdk_dir/build-tools/36.0.0/apksigner" verify --verbose \
    "build/app/outputs/flutter-apk/app-${abi}-release.apk"
done
"$android_sdk_dir/build-tools/36.0.0/aapt" dump badging \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | awk '/^package:/ { print }'
```

- 包名应为 `com.aritxonly.hyperpiliplus`，包内 versionName/versionCode 应与本次 `pili_release.json` 一致；必要时核对签名证书指纹与已使用的 Release 证书一致。
- 不得把输出目录里旧的 APK 当成本次构建产物。若怀疑 Gradle 复用了旧包，核对版本、时间、哈希与构建日志，针对性重新执行任务，不擅自清空整个开发环境。
- `scripts/build_signed_release.sh` 是已有本机 Gradle 重打包/验签辅助脚本，不替代上面的 Flutter 元数据生成和分 ABI 完整构建流程。
- **只打包，不自动覆盖安装或打开已连接设备，不执行卸载、清数据或其他 ADB 写操作。用户自行真机测试，除非本轮另行明确授权。**
- 交付时提供 APK 的绝对路径可点击链接、版本号、通过的检查，以及未验证的真机/云端行为。

## 版本、签名与 GitHub Actions

- `pubspec.yaml` 保留上游三段版本；`tool/release.json` 的 `upstreamVersion` 必须与之对应，`revision` 为本分支修订号。
- 第一个 flavor 版本为 `2.1.3.0`，后续为 `2.1.3.1` 等；升级上游时同步 upstreamVersion，并将 revision 重置为 0。不要未经要求为一次本机测试自动增加发布版本。
- 正式发布后不覆盖已有标签；发布修复版需要递增 revision。具体 versionCode 编码、范围检查以 `scripts/release_metadata.py` 为准。
- 更新检测必须指向 `Constants.githubRepository` 定义的本仓库，按四段数字比较正式版本，不能恢复成上游地址或按编译时间比较。
- 复用已有签名密钥。`SIGN_KEYSTORE_BASE64`、`KEYSTORE_PASSWORD`、`KEY_ALIAS`、`KEY_PASSWORD`、`DEEPSEEK_API_KEY` 不得出现在源码、日志、聊天或提交中；仅在用户明确要求导出时交付受限权限的本地文件，提醒配置后清理。
- 签名文件、密码、`android/key.properties`、`pili_release.json`、本机 SDK 路径及构建产物不得强制加入 Git。Base64 仍是敏感密钥内容，不是加密。
- 云端使用 **Hyper-PiliPlus Android Release**；默认 `publish=false` 只上传 Artifacts，`publish=true` 才创建 Release。上传 Artifact 本身不会触发应用更新提示。
- 正式发布时优先通过 `DEEPSEEK_API_KEY` 调用 `deepseek-v4-flash` 生成中文 Release Notes；仅发送版本与提交标题，提交内容视为不可信输入。密钥缺失或模型调用失败时必须回退到本地生成的提交摘要，不能让发布失败。
- 修复工作流后，用户应从 **Run workflow → main** 新建运行；旧任务的 **Re-run** 仍使用旧提交的配置。
- 已确认的 CI 注意事项：先初始化 `sdkmanager`；SDK 包名使用 `platforms;android-37.0`，Gradle 仍使用 `compileSdk = 37`；获取并验证 Flutter 官方版本标签；首次初始化日志不作为 JSON 解析；保持 `--enforce-lockfile`。
- 声明“已推送”前确认 `git push` 成功；声明“云端通过”前必须看到对应运行结果。不要擅自触发计费构建或正式发布。

## 完成检查

1. 改动只覆盖授权范围，用户已有功能与并行修改得到保留。
2. 相关静态检查、回归测试完成；需要 APK 的任务已完成真实签名打包和产物验证。
3. `git diff --check` 通过，新增测试没有遗漏，提交不包含密钥或产物。
4. 按授权提交、推送或发布；未执行的动作在结果中明确说明。
5. 最终说明改了什么、如何验证、产物在哪里，以及需要用户自行测试的部分。
