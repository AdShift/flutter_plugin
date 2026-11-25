// `getInfo()` must report the versions the build uses, so these tests read the
// build files rather than repeat the versions.
import 'dart:convert';
import 'dart:io';

import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:adshift_flutter_sdk/src/native_sdk_versions.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> nativeSdkPins() =>
    jsonDecode(File('native_sdk.json').readAsStringSync())
        as Map<String, dynamic>;

String nativeSdkVersion(String platform) =>
    (nativeSdkPins()[platform] as Map)['version'] as String;

String pluginVersion() => RegExp(
  r'^version:\s*(\S+)\s*$',
  multiLine: true,
).firstMatch(File('pubspec.yaml').readAsStringSync())![1]!;

/// The versions that follow [prefix] anywhere in [text].
List<String> versionsAfter(String text, String prefix) => [
  for (final match in RegExp(
    '${RegExp.escape(prefix)}(\\d+\\.\\d+\\.\\d+)',
  ).allMatches(text))
    match[1]!,
];

void main() {
  test('the plugin version is the one in pubspec.yaml', () {
    final version = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync());

    expect(version, isNotNull);
    expect(adshiftPluginVersion, version![1]);
  });

  test('the native SDK versions are the ones in native_sdk.json', () {
    final pins = nativeSdkPins();

    expect(androidSdkVersion, (pins['android'] as Map)['version']);
    expect(iosSdkVersion, (pins['ios'] as Map)['version']);
  });

  test('the Android build depends on the pinned Android SDK', () {
    final dependency = RegExp(
      '''["']com\\.adshift:android-sdk:([^"']+)["']''',
    ).firstMatch(File('android/build.gradle.kts').readAsStringSync());

    expect(dependency, isNotNull);
    expect((nativeSdkPins()['android'] as Map)['version'], dependency![1]);
  });

  test('the README names the pinned native SDKs', () {
    final readme = File('README.md').readAsStringSync();
    final android = nativeSdkVersion('android');
    final ios = nativeSdkVersion('ios');
    final series = pluginVersion().split('.').take(2).join('.');
    final requirements = readme.substring(
      readme.indexOf('\n## Requirements\n'),
      readme.indexOf('\n## Installation\n'),
    );

    // The row of this release in the table of native SDK versions.
    expect(
      requirements,
      contains(
        '| $series.x | `com.adshift:android-sdk:$android` | '
        '`AdshiftSDK $ios` |',
      ),
    );
    // Every other place that states a native SDK version.
    expect(
      versionsAfter(readme, 'Android SDK '),
      allOf(isNotEmpty, everyElement(android)),
    );
    expect(
      versionsAfter(readme, 'iOS SDK '),
      allOf(isNotEmpty, everyElement(ios)),
    );
  });

  test('the CHANGELOG has an entry for this version and its native SDKs', () {
    final changelog = File('CHANGELOG.md').readAsStringSync();
    final version = pluginVersion();
    final release = version.split('-').first;

    // pub.dev looks for the version of pubspec.yaml in the changelog.
    expect(
      changelog,
      contains(RegExp('^## \\[${RegExp.escape(version)}\\]', multiLine: true)),
    );
    expect(
      changelog,
      contains(
        '| $release | ${nativeSdkVersion('android')} | '
        '${nativeSdkVersion('ios')} |',
      ),
    );
  });
}
