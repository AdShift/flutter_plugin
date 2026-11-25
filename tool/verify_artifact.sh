#!/usr/bin/env bash
# Builds a fresh Flutter app against the staged package the way an integrator
# does: `flutter create`, add the dependency, build. Nothing of ours in between.
#
# Usage: tool/verify_artifact.sh <staged package> <flutter binary> <check>...
#   stage the package first: dart run tool/check_package.dart --stage <dir>
#   checks:
#     android         release build with code shrinking; the SDK must be in it
#     ios-spm         Swift Package Manager (the default)
#     ios-pods        CocoaPods, dynamic frameworks (Flutter's default Podfile)
#     ios-pods-static CocoaPods, `use_frameworks! :linkage => :static`
#     ios-pods-libs   CocoaPods, static libraries (no `use_frameworks!`)
#     ios-device      release builds for a device, unsigned, on both paths
#     ios-duplicate   a second copy of the SDK must stop the build on both paths
set -euo pipefail

PACKAGE=$(cd "$1" && pwd)
FLUTTER=$2
shift 2

export LANG=en_US.UTF-8
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# A fresh app that uses the package from Dart and from its own native iOS code.
new_app() {
  local name=$1
  (cd "$WORK" && "$FLUTTER" create --no-pub --platforms=ios,android -e \
    --org com.adshift.verify "$name" >/dev/null)
  local app="$WORK/$name"
  python3 - "$app" "$PACKAGE" <<'PY'
import re, sys
app, package = sys.argv[1], sys.argv[2]

pubspec = f"{app}/pubspec.yaml"
text = open(pubspec).read()
text = text.replace(
    "dependencies:\n  flutter:\n    sdk: flutter\n",
    f"dependencies:\n  flutter:\n    sdk: flutter\n  adshift_flutter_sdk:\n    path: {package}\n",
    1,
)
open(pubspec, "w").write(text)

open(f"{app}/lib/main.dart", "w").write('''import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final adshift = Adshift.instance;
  adshift.onDeepLink.listen((link) => debugPrint('${link.status}'));
  adshift.initialize(const AdshiftConfig(apiKey: 'verify', testMode: true));
  final started = await adshift.start();
  final tracked = await adshift.trackEvent(AdshiftEventType.login);
  debugPrint('${started.success} ${tracked.success} ${adshift.getInfo().version}');
  runApp(const SizedBox());
}
''')

# Apps created by older Flutter versions default to iOS 13; the SDK needs 15.
project = f"{app}/ios/Runner.xcodeproj/project.pbxproj"
text = open(project).read()
text = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = 1[0-4]\.\d;", "IPHONEOS_DEPLOYMENT_TARGET = 15.0;", text)
open(project, "w").write(text)

# Compilation fails unless the SDK module reaches the app target.
delegate = f"{app}/ios/Runner/AppDelegate.swift"
text = open(delegate).read().replace("import UIKit", "import UIKit\nimport AdshiftSDK", 1)
text += "\nprivate let adshiftSdkType: Any.Type = Adshift.self\n"
open(delegate, "w").write(text)
PY
  echo "$app"
}

disable_swift_package_manager() {
  python3 - "$1/pubspec.yaml" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path).read()
text = re.sub(r"^flutter:\n", "flutter:\n  config:\n    enable-swift-package-manager: false\n", text, count=1, flags=re.M)
open(path, "w").write(text)
PY
}

require_file() {
  [ -e "$1" ] || { echo "FAILED: missing $1" >&2; exit 1; }
}

build_ios() {
  (cd "$1" && "$FLUTTER" build ios --simulator --debug)
}

for check in "$@"; do
  echo "=== $check"
  case "$check" in
    android)
      app=$(new_app verify_android)
      (cd "$app" && "$FLUTTER" analyze --no-fatal-infos lib >/dev/null)
      (cd "$app" && "$FLUTTER" build apk --release --target-platform android-arm64)
      apk="$app/build/app/outputs/flutter-apk/app-release.apk"
      # Counted, not `grep -q`: an early exit would fail the pipeline under pipefail.
      refs=$(unzip -p "$apk" 'classes*.dex' | strings | grep -c "com/adshift/sdk/core/AdShiftLib" || true)
      [ "$refs" -gt 0 ] ||
        { echo "FAILED: the AdShift Android SDK is not in the release build" >&2; exit 1; }
      ;;
    ios-spm)
      app=$(new_app verify_ios_spm)
      build_ios "$app"
      [ ! -e "$app/ios/Podfile" ] || { echo "FAILED: expected no Podfile" >&2; exit 1; }
      require_file "$app/build/ios/iphonesimulator/Runner.app/Frameworks/AdshiftSDK.framework/PrivacyInfo.xcprivacy"
      ;;
    ios-pods | ios-pods-static | ios-pods-libs)
      app=$(new_app "verify_${check//-/_}")
      disable_swift_package_manager "$app"
      (cd "$app" && "$FLUTTER" build ios --simulator --debug --config-only >/dev/null)
      grep -q '^  use_frameworks!$' "$app/ios/Podfile" ||
        { echo "FAILED: the Podfile template changed; update this script" >&2; exit 1; }
      case "$check" in
        ios-pods-static) sed -i '' 's/^  use_frameworks!$/  use_frameworks! :linkage => :static/' "$app/ios/Podfile" ;;
        ios-pods-libs) sed -i '' '/^  use_frameworks!$/d' "$app/ios/Podfile" ;;
      esac
      build_ios "$app"
      require_file "$app/build/ios/iphonesimulator/Runner.app/AdshiftSDK.bundle/PrivacyInfo.xcprivacy"
      ;;
    ios-device)
      app=$(new_app verify_ios_device_spm)
      (cd "$app" && "$FLUTTER" build ios --release --no-codesign)
      require_file "$app/build/ios/iphoneos/Runner.app/Frameworks/AdshiftSDK.framework/PrivacyInfo.xcprivacy"

      app=$(new_app verify_ios_device_pods)
      disable_swift_package_manager "$app"
      (cd "$app" && "$FLUTTER" build ios --release --no-codesign)
      require_file "$app/build/ios/iphoneos/Runner.app/AdshiftSDK.bundle/PrivacyInfo.xcprivacy"
      ;;
    ios-duplicate)
      sdk_version=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['ios']['version'])" "$PACKAGE/native_sdk.json")

      app=$(new_app verify_dup_pods)
      disable_swift_package_manager "$app"
      (cd "$app" && "$FLUTTER" build ios --simulator --debug --config-only >/dev/null)
      python3 - "$app/ios/Podfile" "$sdk_version" <<'PY'
import sys
path, version = sys.argv[1], sys.argv[2]
anchor = "flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))"
text = open(path).read()
assert anchor in text
text = text.replace(anchor, anchor + f"\n  pod 'AdshiftSDK', :podspec => 'https://raw.githubusercontent.com/AdShift/ios-sdk/v{version}/AdshiftSDK.podspec'", 1)
open(path, "w").write(text)
PY
      if (cd "$app/ios" && pod install >"$WORK/dup-pods.log" 2>&1); then
        echo "FAILED: pod install accepted a second copy of the SDK" >&2; exit 1
      fi
      grep -q "conflicting names" "$WORK/dup-pods.log" ||
        { cat "$WORK/dup-pods.log" >&2; echo "FAILED: unexpected pod install error" >&2; exit 1; }

      app=$(new_app verify_dup_spm)
      (cd "$app" && "$FLUTTER" build ios --simulator --debug --config-only >/dev/null)
      generated="$app/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage"
      require_file "$generated/Package.swift"
      mkdir -p "$WORK/dup-spm/Sources/dup"
      echo "// empty" >"$WORK/dup-spm/Sources/dup/dup.swift"
      cat >"$WORK/dup-spm/Package.swift" <<EOF
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "dup",
    platforms: [.iOS("15.0")],
    dependencies: [
        .package(path: "$generated"),
        .package(url: "https://github.com/AdShift/ios-sdk", exact: "$sdk_version"),
    ],
    targets: [
        .target(name: "dup", dependencies: [
            .product(name: "FlutterGeneratedPluginSwiftPackage", package: "FlutterGeneratedPluginSwiftPackage"),
            .product(name: "AdshiftSDK", package: "ios-sdk"),
        ])
    ]
)
EOF
      (cd "$WORK/dup-spm" && swift package show-dependencies >"$WORK/dup-spm.log" 2>&1) || true
      grep -q "conflicting name: 'AdshiftSDK" "$WORK/dup-spm.log" ||
        { cat "$WORK/dup-spm.log" >&2; echo "FAILED: a second copy of the SDK was accepted by Swift Package Manager" >&2; exit 1; }
      ;;
    *)
      echo "unknown check: $check" >&2
      exit 2
      ;;
  esac
  echo "OK: $check"
done
