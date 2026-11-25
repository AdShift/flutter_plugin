// Checks what `dart pub publish` would upload: only intended files, nothing
// missing, the pinned iOS SDK unchanged, and a sane total size.
//
//   dart run tool/check_package.dart                 check
//   dart run tool/check_package.dart --stage <dir>   check, then copy the
//                                                    package's files to <dir>
//   --local   do not fail on pub's own findings, which include uncommitted
//             changes; for use on a working tree
//
// The staged copy is the package as an integrator receives it; the artifact
// builds in CI depend on it by path.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _frameworks = 'ios/adshift_flutter_sdk/Frameworks';
const _maxBytes = 40 * 1024 * 1024;

const _allowedFiles = {
  'pubspec.yaml',
  'README.md',
  'CHANGELOG.md',
  'LICENSE',
  'analysis_options.yaml',
  'native_sdk.json',
  'android/build.gradle.kts',
  'android/settings.gradle.kts',
  'ios/adshift_flutter_sdk.podspec',
  'ios/adshift_flutter_sdk/Package.swift',
};

const _allowedPrefixes = [
  'lib/',
  'android/src/main/',
  'ios/adshift_flutter_sdk/Sources/',
  '$_frameworks/',
  'example/',
];

final _forbidden = [
  RegExp(r'(^|/)test/'),
  RegExp(r'(^|/)(build|\.gradle|Pods|DerivedData|\.symlinks|ephemeral)/'),
  RegExp(r'\.(iml|log|jks|keystore|p8|p12|mobileprovision)$'),
  RegExp(
    r'(^|/)(local\.properties|key\.properties|GoogleService-Info\.plist|google-services\.json)$',
  ),
];

const _required = [
  'pubspec.yaml',
  'README.md',
  'CHANGELOG.md',
  'LICENSE',
  'native_sdk.json',
  'lib/adshift_flutter_sdk.dart',
  'lib/testing.dart',
  'lib/src/messages.g.dart',
  'android/build.gradle.kts',
  'android/src/main/AndroidManifest.xml',
  'android/src/main/kotlin/com/adshift/adshift_flutter_sdk/AdshiftFlutterSdkPlugin.kt',
  'android/src/main/kotlin/com/adshift/adshift_flutter_sdk/Messages.g.kt',
  'ios/adshift_flutter_sdk.podspec',
  'ios/adshift_flutter_sdk/Package.swift',
  'ios/adshift_flutter_sdk/Sources/adshift_flutter_sdk/AdshiftFlutterSdkPlugin.swift',
  'ios/adshift_flutter_sdk/Sources/adshift_flutter_sdk/Messages.g.swift',
  '$_frameworks/AdshiftSDK.files.json',
  '$_frameworks/AdshiftSDK.xcframework/Info.plist',
  '$_frameworks/AdshiftSDK.xcframework/ios-arm64/AdshiftSDK.framework/PrivacyInfo.xcprivacy',
  'example/lib/main.dart',
];

final _root = File.fromUri(Platform.script).parent.parent.path;

void main(List<String> args) {
  final stageAt = args.indexOf('--stage');
  final stageDir = stageAt >= 0 && stageAt + 1 < args.length
      ? args[stageAt + 1]
      : null;

  final files = _publishedFiles(strict: !args.contains('--local'));
  final problems = <String>[
    for (final file in files)
      if (!_allowedFiles.contains(file) &&
          !_allowedPrefixes.any(file.startsWith))
        'not an intended file: $file',
    for (final file in files)
      if (_forbidden.any((pattern) => pattern.hasMatch(file)))
        'must not be published: $file',
    for (final file in _required)
      if (!files.contains(file)) 'missing: $file',
    ..._iosSdkProblems(files),
    for (final file in files)
      if (file.endsWith('project.pbxproj') &&
          File('$_root/$file').readAsStringSync().contains('DEVELOPMENT_TEAM'))
        'carries an Apple signing team: $file',
  ];

  final bytes = files.fold<int>(
    0,
    (sum, file) => sum + File('$_root/$file').lengthSync(),
  );
  if (bytes > _maxBytes) {
    problems.add(
      'package is ${_megabytes(bytes)} MB, limit '
      '${_megabytes(_maxBytes)} MB',
    );
  }

  if (problems.isNotEmpty) {
    stderr.writeln('Package contents check failed:');
    problems.forEach(stderr.writeln);
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Package contents OK: ${files.length} files, '
    '${_megabytes(bytes)} MB',
  );

  if (stageDir != null) {
    final target = Directory(stageDir);
    if (target.existsSync()) target.deleteSync(recursive: true);
    for (final file in files) {
      final copy = File('${target.path}/$file');
      copy.parent.createSync(recursive: true);
      File('$_root/$file').copySync(copy.path);
    }
    stdout.writeln('Staged in ${target.path}');
  }
}

/// The file list of `dart pub publish --dry-run`, read from the tree it prints.
/// A validation error there fails this check as well.
Set<String> _publishedFiles({required bool strict}) {
  final result = Process.runSync(Platform.resolvedExecutable, [
    'pub',
    'publish',
    '--dry-run',
  ], workingDirectory: _root);
  final output = '${result.stdout}\n${result.stderr}';
  final lines = const LineSplitter().convert(output);
  final start = lines.indexWhere((line) => line.startsWith('Publishing '));
  if (start < 0) {
    stderr.writeln(output);
    throw StateError('`dart pub publish --dry-run` printed no file list');
  }

  final files = <String>{};
  final path = <String>[];
  final entry = RegExp(r'^((?:│   |    )*)(?:├── |└── )(.+)$');
  final size = RegExp(r' \((?:<?\d+) (?:B|KB|MB)\)$');
  for (final line in lines.skip(start + 1)) {
    final match = entry.firstMatch(line);
    if (match == null) break;
    final depth = match.group(1)!.length ~/ 4;
    var name = match.group(2)!;
    final isFile = size.hasMatch(name);
    if (isFile) name = name.replaceFirst(size, '');
    if (path.length > depth) path.removeRange(depth, path.length);
    if (isFile) {
      files.add([...path, name].join('/'));
    } else {
      path.add(name);
    }
  }

  if (strict && result.exitCode != 0) {
    stderr.writeln(lines.skip(start + 1).join('\n'));
    throw StateError('`dart pub publish --dry-run` reported problems');
  }
  return files;
}

/// The iOS SDK in the package is exactly the pinned release: every file of the
/// fetch record present with its recorded sum, and nothing else beside it.
List<String> _iosSdkProblems(Set<String> files) {
  final record = File('$_root/$_frameworks/AdshiftSDK.files.json');
  if (!record.existsSync()) {
    return ['iOS SDK not fetched: run tool/fetch_ios_sdk.dart'];
  }
  final manifest =
      jsonDecode(record.readAsStringSync()) as Map<String, dynamic>;
  final pin =
      (jsonDecode(File('$_root/native_sdk.json').readAsStringSync())
              as Map<String, dynamic>)['ios']
          as Map<String, dynamic>;
  final listed = (manifest['files'] as Map<String, dynamic>);

  return [
    if (manifest['version'] != pin['version'] ||
        manifest['archiveSha256'] != pin['sha256'])
      'iOS SDK in place is not the pinned ${pin['version']}',
    for (final entry in listed.entries)
      if (!files.contains('$_frameworks/${entry.key}'))
        'iOS SDK file not published: ${entry.key}'
      else if (sha256
              .convert(
                File('$_root/$_frameworks/${entry.key}').readAsBytesSync(),
              )
              .toString() !=
          entry.value)
        'iOS SDK file changed: ${entry.key}',
    for (final file in files)
      if (file.startsWith('$_frameworks/') &&
          file != '$_frameworks/AdshiftSDK.files.json' &&
          !listed.containsKey(file.substring(_frameworks.length + 1)))
        'unexpected file beside the iOS SDK: $file',
  ];
}

String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
