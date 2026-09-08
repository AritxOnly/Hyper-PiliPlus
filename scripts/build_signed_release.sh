#!/usr/bin/env bash

# Builds the Android release APK with the local signing configuration and
# verifies its APK signature. Credentials stay in android/key.properties.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
android_dir="$repo_dir/android"
key_properties="$android_dir/key.properties"
local_properties="$android_dir/local.properties"
"$repo_dir/scripts/flutterw" --check-sdk
apk_path="$repo_dir/build/app/outputs/apk/release/app-release.apk"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

test -f "$key_properties" || die "missing android/key.properties"
test -f "$local_properties" || die "missing android/local.properties"

for required_key in storeFile storePassword keyAlias keyPassword; do
  awk -F= -v key="$required_key" '
    $1 == key && length($2) > 0 { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$key_properties" || die "android/key.properties is missing $required_key"
done

sdk_dir="$(awk -F= '$1 == "sdk.dir" { print substr($0, index($0, "=") + 1); exit }' "$local_properties" | tr -d '\r')"
flutter_sdk="$(awk -F= '$1 == "flutter.sdk" { print substr($0, index($0, "=") + 1); exit }' "$local_properties" | tr -d '\r')"
test -n "$sdk_dir" || die "android/local.properties is missing sdk.dir"
test -n "$flutter_sdk" || die "android/local.properties is missing flutter.sdk"
test "$(cd "$flutter_sdk" && pwd -P)" = "$(cd "$repo_dir/.fvm/flutter_sdk" && pwd -P)" || \
  die "flutter.sdk must point to the pinned SDK; see docs/flutter-environment.md"
test -d "$sdk_dir/build-tools" || die "Android build-tools directory not found"
test -f "$flutter_sdk/packages/flutter_tools/gradle/settings.gradle.kts" || \
  die "flutter.sdk does not contain Flutter's Gradle plugin loader"

apksigner="$(find "$sdk_dir/build-tools" -mindepth 2 -maxdepth 2 -type f -name apksigner -print | sort | tail -n 1)"
test -n "$apksigner" || die "apksigner was not found under Android build-tools"

(
  cd "$android_dir"
  # Flutter's AOT build can update after Gradle has considered a previously
  # packaged APK up-to-date, so rerun the Release task graph before signing.
  ./gradlew :app:packageRelease --rerun-tasks --console=plain "$@"
)

test -f "$apk_path" || die "signed release APK was not produced"
"$apksigner" verify --verbose --print-certs "$apk_path"

printf '\nSigned release APK: %s\n' "$apk_path"
shasum -a 256 "$apk_path"
