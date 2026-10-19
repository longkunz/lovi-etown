import 'package:flutter/services.dart';

/// Central orientation policy helper for Camera Mobile A1.
///
/// In A1, the app does not lock portrait mode globally.
/// Devices (phones, tablets, foldable devices) follow the OS default policy
/// allowing both portrait and landscape orientation.
abstract final class ViewerOrientationPolicy {
  ViewerOrientationPolicy._();

  /// Unlocks all orientations supported by the device / operating system.
  static Future<void> allowAllOrientations() async {
    await SystemChrome.setPreferredOrientations(const []);
  }

  /// Restores orientation policy to default OS handling.
  static Future<void> restoreDefaultPolicy() async {
    await SystemChrome.setPreferredOrientations(const []);
  }
}
