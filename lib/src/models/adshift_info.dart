/// What `Adshift.instance.getInfo()` returns; include it in support requests.
final class AdshiftInfo {
  /// Creates the value, for example for a test.
  const AdshiftInfo({
    required this.platform,
    required this.version,
    required this.androidSdkVersion,
    required this.iosSdkVersion,
  });

  /// The platform the app runs on: `android` or `ios`.
  final String platform;

  /// Version of this plugin.
  final String version;

  /// Version of the AdShift Android SDK this plugin is built on.
  final String androidSdkVersion;

  /// Version of the AdShift iOS SDK this plugin is built on.
  final String iosSdkVersion;

  @override
  String toString() =>
      'AdshiftInfo(platform: $platform, version: $version, '
      'androidSdkVersion: $androidSdkVersion, iosSdkVersion: $iosSdkVersion)';
}
