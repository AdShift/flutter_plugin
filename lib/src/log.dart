import 'package:flutter/foundation.dart';

/// Prints an integration hint in debug builds; release builds stay silent.
void debugWarn(String message) {
  if (kDebugMode) debugPrint('[AdShift] $message');
}
