import '../../imports/imports.dart';

/// A wrapper to initialize the chosen State Management library.
///
/// Auth was removed from the main journey (T06: the camera API needs no
/// login), so there is currently no app-wide bloc to provide here. The
/// wrapper stays as a pass-through so a future global provider has a home.
class StateWrapper extends StatelessWidget {
  final Widget child;

  const StateWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
