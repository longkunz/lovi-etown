import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

/// In Camera Mobile A1, the app boots directly to Camera without requiring authentication.
/// Auth/session redirects are decoupled while retaining historic auth files for reference.
class SessionListenerWrapper extends StatelessWidget {
  final Widget child;
  const SessionListenerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    FlutterNativeSplash.remove();
    return child;
  }
}
