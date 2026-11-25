import 'package:flutter/foundation.dart';

import 'models/adshift_info.dart';
import 'native_sdk_versions.dart';
import 'version.dart';

/// What `getInfo()` answers on this platform.
AdshiftInfo readInfo() => AdshiftInfo(
  platform: defaultTargetPlatform.name.toLowerCase(),
  version: adshiftPluginVersion,
  androidSdkVersion: androidSdkVersion,
  iosSdkVersion: iosSdkVersion,
);
