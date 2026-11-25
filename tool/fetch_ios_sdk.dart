// Puts the iOS SDK pinned in native_sdk.json into
// ios/adshift_flutter_sdk/Frameworks, after checking the archive's SHA-256, and
// records each file's sum in AdshiftSDK.files.json for tool/check_package.dart.
//
//   dart run tool/fetch_ios_sdk.dart   fetch when missing or stale
//
// The SDK ships inside the published package; it is not kept in git.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const _frameworkName = 'AdshiftSDK.xcframework';
const _downloadTimeout = Duration(seconds: 120);

final _root = File.fromUri(Platform.script).parent.parent.path;
final _frameworksDir = Directory('$_root/ios/adshift_flutter_sdk/Frameworks');
final _frameworkDir = Directory('${_frameworksDir.path}/$_frameworkName');
final _manifestFile = File('${_frameworksDir.path}/AdshiftSDK.files.json');

Future<void> main() async {
  try {
    await _fetch();
  } catch (error) {
    stderr.writeln('AdShift iOS SDK not fetched: $error');
    exitCode = 1;
  }
}

Future<void> _fetch() async {
  final pins =
      jsonDecode(File('$_root/native_sdk.json').readAsStringSync())
          as Map<String, dynamic>;
  final pin = pins['ios'] as Map<String, dynamic>;
  final version = pin['version'] as String;
  final url = pin['url'] as String;
  final expected = pin['sha256'] as String;

  if (_isCurrent(version, expected)) {
    stdout.writeln('AdShift iOS SDK $version already in place');
    return;
  }
  if (Platform.isWindows) {
    throw StateError('unpacking the iOS SDK needs `unzip`');
  }

  stdout.writeln('Fetching AdShift iOS SDK $version from $url');
  final archive = await _download(Uri.parse(url));
  final actual = sha256.convert(archive).toString();
  if (actual != expected) {
    throw StateError('SHA-256 mismatch: expected $expected, got $actual');
  }

  final work = Directory.systemTemp.createTempSync('adshift-ios-sdk-');
  try {
    final zip = File('${work.path}/$_frameworkName.zip')
      ..writeAsBytesSync(archive);
    final unpacked = Directory('${work.path}/unpacked')..createSync();
    final unzip = Process.runSync('unzip', [
      '-q',
      zip.path,
      '-d',
      unpacked.path,
    ]);
    if (unzip.exitCode != 0) {
      throw StateError('unzip failed: ${unzip.stderr}');
    }
    final source = Directory('${unpacked.path}/$_frameworkName');
    if (!File('${source.path}/Info.plist').existsSync()) {
      throw StateError('the archive holds no $_frameworkName');
    }

    final files = <String, String>{
      for (final file in _listFiles(source))
        '$_frameworkName/$file': sha256
            .convert(File('${source.path}/$file').readAsBytesSync())
            .toString(),
    };

    if (_frameworksDir.existsSync()) _frameworksDir.deleteSync(recursive: true);
    _frameworksDir.createSync(recursive: true);
    for (final file in _listFiles(source)) {
      final target = File('${_frameworkDir.path}/$file');
      target.parent.createSync(recursive: true);
      File('${source.path}/$file').copySync(target.path);
    }
    const encoder = JsonEncoder.withIndent('  ');
    _manifestFile.writeAsStringSync(
      '${encoder.convert({'version': version, 'url': url, 'archiveSha256': expected, 'files': files})}\n',
    );
    stdout.writeln('AdShift iOS SDK $version: ${files.length} files in place');
  } finally {
    work.deleteSync(recursive: true);
  }
}

/// Whether the pinned release is in place unchanged. Sums are compared, not
/// only names, so an edited binary never reaches a package.
bool _isCurrent(String version, String archiveSha256) {
  if (!_manifestFile.existsSync() || !_frameworkDir.existsSync()) return false;
  final manifest =
      jsonDecode(_manifestFile.readAsStringSync()) as Map<String, dynamic>;
  if (manifest['version'] != version ||
      manifest['archiveSha256'] != archiveSha256) {
    return false;
  }
  final listed = (manifest['files'] as Map<String, dynamic>);
  final onDisk = _listFiles(
    _frameworkDir,
  ).map((file) => '$_frameworkName/$file').toList();
  if (onDisk.length != listed.length) return false;
  return onDisk.every(
    (file) =>
        listed[file] ==
        sha256
            .convert(File('${_frameworksDir.path}/$file').readAsBytesSync())
            .toString(),
  );
}

/// Relative paths of every file under [dir], sorted. A symbolic link stops the
/// run: `dart pub publish` would not carry it into the package as it is.
List<String> _listFiles(Directory dir) {
  final out = <String>[];
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    final relative = entity.path.substring(dir.path.length + 1);
    if (entity is Link) {
      throw StateError('symbolic link in the SDK archive: $relative');
    }
    if (entity is File) out.add(relative.replaceAll(r'\', '/'));
  }
  return out..sort();
}

Future<List<int>> _download(Uri url) async {
  final client = HttpClient()
    ..userAgent = 'adshift-flutter-plugin-build'
    ..connectionTimeout = _downloadTimeout
    ..idleTimeout = _downloadTimeout;
  try {
    final request = await client.getUrl(url);
    request.followRedirects = true;
    request.maxRedirects = 5;
    final response = await request.close().timeout(_downloadTimeout);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(_downloadTimeout)) {
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  } finally {
    client.close(force: true);
  }
}
