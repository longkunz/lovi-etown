/// Centralized route path constants for GoRouter.
///
/// Use these variables instead of raw strings throughout the app.
/// Example: `context.go(AppRoutes.onboarding)` instead of `context.go('/')`.
abstract final class AppRoutes {
  AppRoutes._();

  static const String map = '/';
  static const String camera = '/cameras';

  /// Full-screen single-camera viewer; `:id` is the camera id path param.
  static const String cameraViewer = '/camera/:id';
  static const String splash = '/splash';
  static const String home = '/home';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';

  /// Debug-only component gallery.
  static const String uiShowcase = '/debug/ui-showcase';
}
