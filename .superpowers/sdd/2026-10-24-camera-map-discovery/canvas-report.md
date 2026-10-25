# Shared Vietmap canvas / Task 5

Implemented the SDK-neutral `CameraMapViewConfig`, coordinates, markers, handle,
builder and compatibility alias. Card and full-screen detail map both use the
shared Vietmap canvas. Optional nearby radius uses a 64-segment geodesic GeoJSON
polygon (meters), not a pixel-radius marker. Initial style ready reports visible
bounds through the controller; idle queries the SDK visible region. Style changes
capture the actual viewport and reconstruct markers, traffic and radius. Separate
request/render generations guard late HTTP, old controller callbacks and handles.

Vietmap styles are fetched by a separate Dio client, restricted to HTTPS Vietmap
hosts (including nested resources), with a total 10 second timeout/cancellation.
`tm` is the base, `hm` falls back to the street base on failure, and `tf` sources
and layers merge into the selected base with IDs deduplicated. Auxiliary failures
show a separate message and preserve the base. Errors expose typed categories,
never request URLs or key-bearing exception strings. Backend reader credentials
are not given to this client. Missing runtime key shows a configuration message.

Canvas active/lifecycle state removes the native map and cancels style loads.
SDK widget owns controller disposal. Default detail-card full-screen navigation
removes the mini-map first, then restores it and reloads traffic preferences after
return. Card/fullscreen `active` also suppresses injected map builders. Parent
owns route activity integration in snapshot-sheet/viewer and discovery shell.

## Native setup and evidence

- Pin `vietmap_flutter_gl: 4.1.1`; remove Google Maps Flutter/native configuration.
- Android minSdk 24, JitPack, foreground coarse/fine location declarations.
- iOS foreground usage string; CocoaPods lockfile removes Google and pins VietMap
  2.9.4 through the Flutter SDK's podspec. Existing iOS deployment target is 15.
- The SDK 4.1.1 `Package.swift` is entirely commented out. Initial iOS SPM build
  failed with “Missing or empty JSON output from manifest compilation”. Project
  `flutter.config.enable-swift-package-manager: false` uses official CocoaPods
  setup and resolves this; Xcode project gains the embed-pods-frameworks phase.
- `flutter pub get`: PASS.
- TDD initial loader test: RED because loader/API did not exist.
- `flutter test --no-pub test/features/cameras/camera_map_canvas_test.dart
  test/features/cameras/vietmap_style_loader_test.dart
  test/features/cameras/camera_traffic_map_test.dart`: 17 PASS.
- Scoped `flutter analyze --no-pub` for 5 implementation files + 3 tests: PASS.
- `flutter build apk --debug`: PASS, app-debug.apk, 112.6 seconds.
- `flutter build ios --simulator --no-codesign --no-pub`: PASS, Runner.app,
  41.0 seconds (after parent fixed concurrent screen const-expression errors).
- SDK and existing plugins emit deprecation/Kotlin migration warnings.

No authorized real Vietmap key was used. Street/hybrid/traffic tile entitlement,
native device gestures and live traffic remain unverified; widget/native builds
are not device acceptance.

Sources checked: https://pub.dev/packages/vietmap_flutter_gl/versions/4.1.1 and
https://maps.vietmap.vn/docs/map-api/traffic-layer/ . Package documentation confirms
minSdk 24/JitPack; traffic documentation requires merging `tf` sources and layers
into the base. Graph coverage was checked for original card/viewer/tests and new
shared map config/model evidence; newly created files are absent from original
root index and were verified directly in the shared worktree.
