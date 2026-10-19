import 'dart:async';

abstract interface class PreviewClock {
  DateTime now();
  Timer schedule(Duration delay, void Function() callback);
}

class SystemPreviewClock implements PreviewClock {
  const SystemPreviewClock();

  @override
  DateTime now() => DateTime.now();

  @override
  Timer schedule(Duration delay, void Function() callback) {
    return Timer(delay, callback);
  }
}
