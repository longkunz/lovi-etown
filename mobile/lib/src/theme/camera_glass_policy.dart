import 'package:flutter/widgets.dart';

/// Policy governing whether glass surfaces should fall back to opaque rendering
/// or reduce/disable visual motions and shader transitions.
class CameraGlassPolicy {
  final bool opaque;
  final bool reduceMotion;

  const CameraGlassPolicy({
    required this.opaque,
    required this.reduceMotion,
  });

  /// Resolves the policy against the active [MediaQueryData] and optional overrides.
  ///
  /// - [opaque] is enabled when high-contrast accessibility is turned on or when
  ///   forced explicitly via [forceOpaque].
  /// - [reduceMotion] is enabled when animations are disabled or accessible navigation
  ///   is active. Reduced motion does not disable user inputs or force opaque surfaces.
  factory CameraGlassPolicy.resolve(
    MediaQueryData mediaQuery, {
    bool forceOpaque = false,
  }) {
    return CameraGlassPolicy(
      opaque: mediaQuery.highContrast || forceOpaque,
      reduceMotion: mediaQuery.disableAnimations || mediaQuery.accessibleNavigation,
    );
  }
}
