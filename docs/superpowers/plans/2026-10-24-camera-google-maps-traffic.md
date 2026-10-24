# Camera Google Maps & Traffic Layer Implementation Plan (T18)

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` để triển khai tuần tự trong phiên này, hoặc `superpowers:subagent-driven-development` nếu người dùng chọn chia task cho agent. Theo dõi bằng checkbox; không tự bắt đầu implementation chỉ vì plan đã được sửa.

**Goal:** Tích hợp Google Maps với lớp giao thông vào `CameraSnapshotSheet` và viewer bản đồ toàn màn hình; bảo toàn luồng snapshot/live hiện tại.

**Architecture:** Giữ Feature-first trong `mobile/lib/src/features/cameras/`. Sheet sở hữu một `CameraTrafficCubit` và truyền cùng instance cho card/viewer; persistence nằm sau contract. Native map nằm sau builder có thể inject fake; một surface chung quản lý mount/unmount theo foreground và trạng thái bị che. API key được cấp ở native build, trước Dart bootstrap.

**Tech Stack:** Flutter 3.47.7, Dart 3.13.5, `google_maps_flutter: ^2.19.0`, `google_maps_flutter_ios_sdk9: ^2.19.0`, `liquid_glass_widgets: 1.13.0`, `flutter_bloc`, `shared_preferences`, `easy_localization`. Commit phiên bản resolve trong `pubspec.lock`; không ngầm coi `^2.10.0` là pin phiên bản 2.10.

**Spec:** [T18 — Đặc tả Camera Google Maps & Traffic Layer](../specs/2026-10-24-camera-google-maps-traffic-design.md).

**Làm rõ sau review:** D18.4 được cụ thể hóa bằng cấu hình native riêng từng nền tảng; `.env` do `flutter_dotenv` đọc sau native startup không cấp key cho manifest/AppDelegate. Build native thiếu key dừng với thông báo cấu hình, không dùng dummy key. Headless test dùng fake map và không cần key. Đây là điều chỉnh kỹ thuật của plan; Task 6 cập nhật điểm này trong spec trước khi đóng T18.

## Global Constraints

- **Media là trung tâm:** Bản đồ cao 200 dp ngay dưới snapshot/live, trước nút “Chỉ đường”; không thay đổi polling 12s hay live HLS.
- **Tọa độ:** Chỉ tạo map khi `camera.hasLocation`; thiếu một trong hai tọa độ thì `SizedBox.shrink()`. Tâm tại camera, zoom `15.5`, marker `camera.id` màu `CameraUiTokens.primaryTeal`.
- **Glass:** Dùng `CameraUiTokens`, `LiquidRoundedSuperellipse`, radius16. Sheet đã là glass surface: vùng map clip bo góc; controls glass đặt ở lớp overlay riêng, không thêm một surface glass lồng toàn bộ card vào sheet. Giữ attribution/logo Google và không che bằng controls.
- **Traffic:** Key lưu trữ chính xác `camera_traffic_layer_enabled`; mặc định `true` chỉ khi chưa có giá trị hoặc đọc lỗi. Card/viewer luôn dùng cùng state, không tự đọc preferences riêng.
- **Vòng đời:** Chỉ mount native map khi host active và app resumed; unmount khi background, đóng host hoặc mini-map bị viewer che. Không giữ đồng thời hai native map cho một phiên chi tiết.
- **Nền tảng:** Android tối thiểu API 24, iOS 15; giữ SPM và chọn implementation SDK 9 thay vì tự nâng lên iOS 16. Bản đồ/traffic lấy từ Google SDK; dữ liệu camera vẫn qua backend hiện hữu.
- **Hồi quy:** Chạy toàn bộ `flutter test` sau mỗi task có thay đổi mã nguồn; lấy baseline thực tế trước triển khai. Con số 134 trong spec là mốc cũ, không phải số test cố định hoặc bằng chứng mới.

## Review Focus

1. **Native key/build:** Key thật đi tới đúng native SDK; thiếu key phải báo rõ khi build, sai key phải bị phát hiện bằng smoke test thật (Task 1, 5).
2. **Persistence/state:** Saved `false`, đọc/ghi lỗi và toggle nhanh không làm card/viewer lệch nhau hoặc ghi đè lựa chọn mới bằng kết quả cũ (Task 2, 4).
3. **Headless:** Fake map phải nhận đúng tọa độ, marker, traffic và lệnh recenter ở cả card/sheet/viewer; không chỉ assert có placeholder (Task 3–5).
4. **Lifecycle:** Background, viewer che mini-map, đổi camera và đóng trong lúc native map khởi tạo không giữ controller cũ hoặc gọi controller đã dispose (Task 3–5).
5. **Tương tác:** Pan/zoom trong map, cuộn/kéo sheet ngoài map, màn hình nhỏ và quyền GPS bị từ chối đều có đường kiểm chứng (Task 4, 5).

## Cấu trúc File và Trách nhiệm

Các đường dẫn bên dưới tương đối với `mobile/`, trừ `docs/`.

| Thao tác | File | Trách nhiệm |
|---|---|---|
| Modify | `pubspec.yaml`, `pubspec.lock` | Maps và implementation iOS SDK 9 |
| Modify | `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml` | Đọc key build-time, manifest placeholder, platform floor và quyền vị trí |
| Create | `android/maps.properties.example`, `ios/Flutter/Maps.example.xcconfig` | Mẫu cấu hình key riêng từng nền tảng |
| Modify | `.gitignore`, `.env.example`, `SETUP.md`, `README.md` | Ignore key thật; hướng dẫn native ở SETUP, README trỏ tới đó |
| Modify | `ios/Flutter/Debug.xcconfig`, `ios/Flutter/Release.xcconfig`, `ios/Runner/Info.plist`, `ios/Runner/AppDelegate.swift`, `ios/Runner.xcodeproj/project.pbxproj` | Xcode settings → Info.plist → SDK, guard build, SPM và iOS 15 |
| Create | `lib/src/features/cameras/domain/camera_traffic_preferences.dart` | Contract đọc/ghi tùy chọn traffic |
| Create | `lib/src/features/cameras/data/datasources/traffic_preferences_store.dart` | Adapter SharedPreferences |
| Create | `lib/src/features/cameras/presentation/providers/camera_traffic_cubit.dart`, `camera_traffic_state.dart` cùng thư mục | State chung và hàng đợi ghi |
| Create | `lib/src/features/cameras/presentation/widgets/camera_map_view.dart` | Options, builder, handle và native implementation |
| Create | `lib/src/features/cameras/presentation/widgets/camera_traffic_map_surface.dart` | Lifecycle/mount gate dùng chung cho card/viewer |
| Create | `lib/src/features/cameras/presentation/widgets/camera_traffic_map_card.dart` | Card và callbacks toggle/mở rộng |
| Create | `lib/src/features/cameras/presentation/screens/camera_traffic_map_viewer_screen.dart` | Viewer và controls |
| Modify | `lib/src/features/cameras/presentation/widgets/camera_snapshot_sheet.dart` | Ownership, truyền dependencies và chuyển host |
| Create | `test/features/cameras/camera_traffic_cubit_test.dart`, `camera_traffic_map_test.dart`, `camera_traffic_map_viewer_test.dart`, `support/fake_camera_map_view.dart` cùng thư mục | Persistence, lifecycle, UI và recording fake |
| Modify | `test/features/cameras/camera_snapshot_sheet_test.dart` và các test mở sheet với tọa độ | Inject fake qua cùng seam |
| Modify | `docs/README.md`, `docs/superpowers/specs/2026-10-24-camera-google-maps-traffic-design.md` | Index và làm rõ D18.4 |
| Create | `docs/ui/t18-google-maps-traffic-verification.md` | Evidence tự động và native |

## Task 1: Cấu hình Maps SDK và chứng minh native build

**Interfaces:** Produces native key setting `GOOGLE_MAPS_API_KEY` trên từng nền tảng; không truyền key qua widget. Task 3 dùng `GoogleMap` từ các package đã resolve.

- [x] **1.1. Baseline:** Đọc `docs/project-status.md`, spec, `mobile/AGENTS.md`, `SETUP.md`; kiểm tra SDK bằng `flutter --version`. Chạy `flutter test` trong `mobile/`, ghi ngày, số test và lỗi baseline. Không ghi PASS nếu chưa chạy. Các thao tác native ở task này là phạm vi T18 được nêu rõ, không mở rộng sang cấu hình native khác.
- [x] **1.2. Dependencies:** Thêm hai dependency trong Tech Stack, chạy `flutter pub get`; kiểm tra lockfile chọn implementation `google_maps_flutter_ios_sdk9`. Android đặt `minSdk = 24`; xác nhận các configuration iOS vẫn là 15.0. Dùng [hướng dẫn package Maps](https://pub.dev/packages/google_maps_flutter) và [SDK 9](https://pub.dev/packages/google_maps_flutter_ios_sdk9); không thay AppDelegate hiện tại bằng template cũ làm mất `FlutterImplicitEngineDelegate`.
- [x] **1.3. Android key:** Trong `android/app/build.gradle.kts`, đọc biến môi trường `GOOGLE_MAPS_API_KEY`, fallback sang property cùng tên ở `android/maps.properties`. Trim và từ chối rỗng/giá trị mẫu bằng GradleException không chứa key. Gán `manifestPlaceholders["GOOGLE_MAPS_API_KEY"]`; manifest thêm meta-data `com.google.android.geo.API_KEY` với `${GOOGLE_MAPS_API_KEY}`. Tạo file `.example`; ignore `android/maps.properties`. Device builds cần key thật kể cả debug; headless `flutter test` không chạy Gradle.
- [ ] **1.4. iOS key:** `Debug.xcconfig` và `Release.xcconfig` include optional `Maps.local.xcconfig` sau `Generated.xcconfig`; Profile hiện dùng Release cũng phải nhận setting. File local khai báo `GOOGLE_MAPS_API_KEY = <key iOS>` và được ignore, file example không chứa key thật. `Info.plist` thêm `GOOGLE_MAPS_API_KEY` = `$(GOOGLE_MAPS_API_KEY)`; AppDelegate đọc Bundle và gọi `GMSServices.provideAPIKey` trước `super.application(...)`. Thêm build phase trước compile để từ chối setting trống, placeholder hoặc chưa expand trong mọi configuration; chỉ in tên setting cần sửa. Giữ callback đăng ký plugin qua implicit engine hiện hữu.
- [x] **1.5. Cloud/setup:** Trong `SETUP.md`, ghi cách bật billing và Maps SDK cho Android/iOS, dùng key riêng: Android restrict package `com.lovisoft.etown` + SHA-1 debug/release/Play signing tương ứng; iOS restrict bundle ID thực tế. Theo [hướng dẫn Google](https://developers.google.com/maps/flutter-package/config). `.env.example` chỉ chú thích vị trí cấu hình native, không khuyến khích thêm Maps key cho `flutter_dotenv`. Native key trong app phải được restrict; không ghi giá trị thật vào log/evidence.
- [x] **1.6. GPS:** Khai báo Android coarse/fine location và iOS `NSLocationWhenInUseUsageDescription` để phục vụ D18.3; viewer chỉ dùng quyền đã cấp, không tự hiện permission prompt khi mở bản đồ. Không yêu cầu background location.
- [ ] **1.7. Verify cấu hình:** Thử build thiếu key trên từng nền tảng, xác nhận lỗi cấu hình rõ ràng. Sau đó cấp key thật và chạy `flutter build apk --debug`, `flutter build ios --debug --no-codesign` trên macOS/Xcode; kiểm tra SPM resolve SDK 9, không chuyển sang CocoaPods cho Maps. Chạy lại `flutter test`. Build PASS chưa xác nhận tiles/traffic; native smoke nằm ở Task 5. Không có key/toolchain thì ghi blocked cho phần tương ứng, không đánh dấu task/native acceptance hoàn tất; vẫn có thể tiếp tục các phần headless độc lập ở Task 2–4.

## Task 2: State traffic dùng chung và persistence tuần tự

**Files:** Contract, preferences store, Cubit/state và `camera_traffic_cubit_test.dart` trong bảng trên.

**Interfaces:** `CameraTrafficPreferences` có `Future<bool?> readEnabled()` và `Future<void> writeEnabled(bool enabled)`; `SharedPreferencesTrafficPreferencesStore` implement contract. `CameraTrafficCubit(CameraTrafficPreferences preferences)` cung cấp `Future<void> load()`, `void toggle()`, `Future<void> close()`. State sealed gồm loading và ready; ready có `bool enabled`, `bool persistenceFailed`.

- [x] **2.1. Test đỏ:** Dùng fake store với Completer: chưa có key → true; saved false → false; đọc lỗi → ready true kèm lỗi; toggle trước load xong bị bỏ qua; `true → false → true` emit tức thì và ghi lần lượt false rồi true; một lần ghi lỗi không chặn lần sau; close trong lúc load/ghi không emit vào Cubit đã đóng.
- [x] **2.2. Chạy** `flutter test test/features/cameras/camera_traffic_cubit_test.dart`, xác nhận thất bại vì contract/hành vi chưa có.
- [x] **2.3. Implement:** Store dùng key `camera_traffic_layer_enabled`, coi `setBool` trả false là lỗi. Load chỉ một lần; UI chưa cho toggle khi loading để tránh đọc cũ ghi đè lựa chọn. Cubit emit optimistic, enqueue các giá trị đã chụp tại thời điểm toggle theo thứ tự; lỗi ghi giữ lựa chọn hiện tại trong phiên, báo `persistenceFailed`, không rollback state mới. Log lỗi không kèm dữ liệu nhạy cảm; close đợi hàng đợi ghi và chặn emit muộn.
- [x] **2.4. Verify:** Targeted test và toàn bộ `flutter test` PASS; sau khi hàng đợi drain, tạo Cubit mới từ store và xác nhận đọc đúng lựa chọn cuối. Chốt commit chỉ gồm thay đổi task này khi triển khai.

## Task 3: Adapter native map, fake và lifecycle surface

**Files:** `camera_map_view.dart`, `camera_traffic_map_surface.dart`, recording fake và `camera_traffic_map_test.dart`.

**Interfaces:** `typedef CameraMapViewBuilder = Widget Function(BuildContext context, CameraMapViewOptions options)`. Options gồm `Camera camera`, `double zoom` (=15.5), `String markerId` (=camera.id), `Color markerColor` (=primaryTeal), `bool trafficEnabled`, `CameraMapType mapType` (normal/satellite), `bool myLocationEnabled`, callback `onReady(CameraMapHandle handle)`. `CameraMapHandle.moveTo(double latitude, double longitude)` trả `Future<void>`. Native entry point `buildGoogleCameraMapView`; handle chỉ hợp lệ trong đời map, host không tự dispose controller lần hai.

`CameraTrafficMapSurface` nhận `Camera camera`, `bool active`, `double? height`, cùng traffic/mapType/myLocation/onReady và `CameraMapViewBuilder mapViewBuilder = buildGoogleCameraMapView`. Card dùng height 200; viewer dùng constraints bounded toàn màn hình. `active` do host quản lý, lifecycle foreground do surface quan sát.

- [x] **3.1. Test đỏ:** Recording fake lưu options, lệnh moveTo, số mount/unmount và handle đang sống. Kiểm tra camera có tọa độ, thiếu từng tọa độ, active=false, app background/resume, đổi camera, rebuild do traffic và callback onReady đến muộn sau unmount. Fake phải nhận options thật, không chỉ render một Container vô điều kiện.
- [x] **3.2. Chạy** `flutter test test/features/cameras/camera_traffic_map_test.dart`, xác nhận các case mới đỏ trước implementation.
- [x] **3.3. Implement adapter:** Native builder tạo `GoogleMap` với target từ camera, zoom/traffic/marker ID/màu từ options và bitmap marker teal theo token (không dùng marker đỏ mặc định). Recording fake assert các options này; hình marker native được đối soát ở Task 5. Giữ logo/attribution; widget luôn có constraints bounded. `myLocationEnabled` chỉ true khi đã có quyền. Native map sở hữu controller; khi `GoogleMap` unmount thì plugin giải phóng controller, handle bị vô hiệu, không giữ controller qua lần tạo map mới.
- [x] **3.4. Implement lifecycle:** Surface chỉ gọi builder khi có vị trí, `active == true` và lifecycle resumed. Khi inactive/hidden/paused/detached thì unmount map; resumed tạo map mới tại camera hiện tại, giữ tùy chọn traffic/mapType ở host. Dùng generation guard cho onReady và lệnh async: bỏ callback/lệnh từ lần mount cũ. Đổi camera dùng key chứa camera.id; thay traffic chỉ cập nhật options, không remount bản đồ. Surface tự gỡ observer khi dispose.
- [x] **3.5. Verify:** Test xác nhận mỗi lần đổi host/background có unmount, tối đa một fake map active, không gọi handle đã hủy; key/tọa độ thay đúng khi đổi camera. Chạy targeted và toàn bộ `flutter test`. Test không dùng nhánh phát hiện môi trường test trong production code hoặc mock MethodChannel Maps rải rác.

## Task 4: Card, sheet và viewer dùng chung state

**Files:** Card, viewer, snapshot sheet và các widget test tương ứng trong bảng.

**Interfaces:** `CameraTrafficMapCard` nhận `Camera camera`, `CameraTrafficCubit traffic`, `bool active`, `VoidCallback onExpand`, `CameraMapViewBuilder mapViewBuilder` (default native), `double height = 200`. `CameraTrafficMapViewerScreen` nhận camera, cùng instance traffic và cùng builder; screen không close Cubit. Sheet nhận optional Cubit để test inject; nếu không truyền thì tự tạo từ preferences store, gọi load trong initState và close khi sheet dispose. Instance inject do caller sở hữu.

Viewer nhận thêm các callback optional `FutureEither<LocationPermission> Function()? checkLocationPermission`, `FutureEither<bool> Function()? isLocationServiceEnabled`, `FutureEither<Position?> Function()? readLastKnownPosition`; default delegate tới ba method tương ứng của `LocationService.instance`. Dùng các type hiện có từ geolocator và `FutureEither`, không thêm thư viện vị trí.

- [x] **4.1. Test đỏ:** Card nhận saved false, toggle cập nhật options tức thì, thiếu tọa độ không gọi builder. Sheet đặt card giữa media và directions. Luồng sheet → viewer → toggle false → đóng viewer → mini-map false → đóng sheet → mở phiên mới vẫn false. Kiểm tra viewer close/recenter và trường hợp chưa onReady.
- [x] **4.2. Implement card/sheet:** Card dùng surface Task 3, controls toggle/mở rộng với tooltip/semantics và touch target theo tokens. Loading preferences có placeholder nhẹ, chưa tạo map/toggle; persistence lỗi có thông báo nhẹ. Sheet giữ một Cubit xuyên suốt đổi camera T17, truyền builder xuống mọi host; thêm tests cho camera có vị trí vào `camera_snapshot_sheet_test.dart`.
- [x] **4.3. Chuyển host:** Sheet có cờ `_mapCovered`. Trước khi mở viewer bản đồ hoặc viewer ảnh hiện hữu, đặt cờ true và đợi mini surface unmount rồi mới mở viewer. Dùng `try/finally`, chỉ phục hồi cờ nếu sheet còn mounted. Khi đóng viewer/background không đồng thời recreate mini-map và giữ map cũ; không thay đổi lifecycle/polling của preview ngoài phần đã có. Viewer ảnh vẫn giữ zoom/xoay hiện hữu.
- [x] **4.4. Implement viewer:** Header tên camera/quận và nút X; pan/zoom/rotate, loại bản đồ normal/satellite, recenter về camera, traffic toggle từ cùng Cubit; giữ action “Chỉ đường” bằng `openCameraDirections` hiện hữu. Controls cần handle thì disable đến onReady, vô hiệu khi background. Khi đóng viewer chỉ giải phóng map của nó, không close Cubit của sheet.
- [x] **4.5. “Vị trí của tôi” (D18.3):** Gọi `checkLocationPermission` trước khi bật lớp vị trí/nút; chỉ hiện khi whileInUse/always. Khi bấm nút, kiểm tra lại quyền và `isLocationServiceEnabled`, rồi mới gọi `readLastKnownPosition`; có vị trí thì moveTo, null/lỗi/GPS tắt thì thông báo nhẹ và giữ map. Không gọi `getCurrentPosition()` hiện hữu vì hàm đó có nhánh tự request permission. Kiểm tra lại quyền khi resumed; nếu không được cấp thì tắt lớp vị trí. Bỏ kết quả async sau dispose hoặc sau khi surface đã đổi generation; không đổi shared LocationService chỉ để phục vụ T18.
- [x] **4.6. Cử chỉ:** Map native dùng EagerGestureRecognizer để nhận pan/zoom bắt đầu bên trong map. Chấp nhận rằng drag bắt đầu trong map không cuộn sheet; drag ngoài map/handle vẫn cuộn và đóng sheet. Controls đặt ngoài vùng hit-test native. Không tuyên bố hết xung đột chỉ từ widget test fake; phải kiểm tra trên thiết bị ở Task 5.
- [x] **4.7. Verify:** Chạy ba widget test file của card/sheet/viewer và toàn bộ `flutter test`. Bổ sung fake callbacks cho quyền GPS denied/granted/revoked, vị trí null/lỗi, và fake handle để assert recenter nhận đúng tọa độ. Các test khác mở sheet có vị trí cũng phải inject builder; không sửa expectation để né bản đồ.

## Task 5: Hồi quy và nghiệm thu native bằng key thật

**Interfaces:** Consumes UI/state/adapters Task 1–4; produces evidence cho AC-1…AC-6, không thay native bằng fake trong smoke test.

- [x] **5.1. Tự động:** Trong `mobile/`, chạy `flutter analyze` và `flutter test`; ghi số test thực tế, kết quả và commit được kiểm. Xác nhận các case Review Focus đã có assertion: options/marker/zoom, persistence chậm/lỗi, liên thông card-viewer, lifecycle, đổi camera và handle cũ. Rà lại một lần toàn bộ suite sau thay đổi cuối.
- [ ] **5.2. Build cuối:** Chạy lại `flutter build apk --debug` và `flutter build ios --debug --no-codesign` sau khi đã tích hợp UI. Build artifact không thay thế chạy app; ghi rõ cấu hình và restriction của key nhưng không ghi key. Nếu phát hành release thì kiểm chứng thêm build/signing release và key restriction tương ứng trước khi ghi release-ready.
- [ ] **5.3. Android và iOS native smoke:** Mỗi nền tảng chạy trên device/emulator/simulator có mạng và hỗ trợ Maps SDK; ghi OS, thiết bị, build, thời gian. Mở camera có tọa độ (ví dụ Hàng Xanh `10.8018, 106.7114`), đối chiếu tâm/marker teal và traffic trên đường có dữ liệu. Chụp ảnh mini-map và viewer; xác nhận tiles không trắng, không có lỗi authorization. Khu vực không có dữ liệu traffic không đủ bằng chứng AC-2; thử tuyến có coverage.
- [ ] **5.4. Luồng thật:** Toggle ở mini-map rồi viewer và ngược lại, đóng/mở sheet, khởi động lại app; xác nhận lựa chọn cuối được giữ. Kiểm tra recenter, đổi map type, directions, nút X và GPS granted/denied/GPS tắt. Thiếu tọa độ không crash và không tạo map.
- [ ] **5.5. Lifecycle/gesture thật:** Lặp mở/đóng viewer, mở viewer ảnh, đổi camera T17, đưa app background rồi resumed ít nhất 10 vòng. Quan sát native map/controller qua debug instrumentation chỉ ghi mount/dispose ID và công cụ memory của nền tảng; không còn host hoạt động sau close/background và không tăng tích lũy số map. Trên màn hình nhỏ kiểm tra snapshot/live vẫn xem được, pan/zoom map, kéo sheet ngoài map, attribution và controls không chồng nhau. Đóng instrumentation sau khi thu evidence.
- [ ] **5.6. Gate nghiệm thu:** Nếu thiếu key, thiết bị, SDK/toolchain hoặc traffic chưa quan sát được, ghi rõ NOT RUN/BLOCKED và điều kiện chạy lại. Không đánh dấu AC-1/2/5 PASS từ fake map hoặc chỉ từ native build. Không đóng T18 khi còn thiếu bằng chứng bắt buộc của một trong hai nền tảng.

## Task 6: Tài liệu và đóng T18

**Files:** `SETUP.md`, `README.md`, `.env.example`, spec T18, `docs/README.md`, báo cáo nghiệm thu.

- [x] **6.1. Setup:** Hoàn thiện hướng dẫn đã tạo ở Task 1: đường dẫn cấu hình riêng từng nền tảng, key restriction/billing, SPM SDK 9, lệnh build/run và xử lý lỗi thiếu key/authorization. README trỏ tới SETUP để không nhân đôi hướng dẫn. Kiểm tra các file local chứa key được ignore, chỉ commit example với placeholder.
- [x] **6.2. Spec/index:** Cập nhật D18.4 về native build-time injection thay cho giả định `flutter_dotenv` và dummy key; ghi đây là làm rõ kỹ thuật sau review. Đối chiếu D18.1–D18.3 gồm marker teal, toggle persistent và “Vị trí của tôi”. Index đã có link spec/plan: chỉ cập nhật mô tả 6 task nếu cần, không tạo mục trùng.
- [x] **6.3. Báo cáo:** Tạo `docs/ui/t18-google-maps-traffic-verification.md` với ngày/commit, baseline và lệnh thực chạy, số test, build Android/iOS, screenshot native, lifecycle/gesture và các mục chưa chạy. Map từng AC tới evidence; chỉ đánh dấu hoàn tất khi Task 5 đủ bằng chứng. Không đưa key thật vào tài liệu.

## Đối chiếu yêu cầu và bằng chứng cần có

| Yêu cầu | Task triển khai | Bằng chứng nghiệm thu |
|---|---|---|
| AC-1: tâm/marker đúng; D18.1: 200 dp, zoom 15.5, teal | 3–4 | Recording fake + native screenshot Android/iOS |
| AC-2: màu traffic thật | 1, 3–4 | Native smoke có coverage traffic (5.3) |
| AC-3: thiếu một trong hai tọa độ | 3–4 | Widget test không gọi builder + smoke |
| AC-4: toggle tức thì và persistent | 2, 4 | Test đồng bộ/ghi tuần tự/lỗi + restart app thật |
| AC-5: fullscreen, recenter, đóng; D18.3: vị trí khi có quyền | 3–4 | Fake handle/quyền GPS + native pan/zoom/close |
| AC-6: hồi quy headless | 2–5 | Toàn bộ `flutter test` sau thay đổi cuối |
| Giải phóng khi background/close/covered, không giữ hai map | 3–4 | Fake mount/unmount + native lifecycle evidence |
| Key native và iOS SPM | 1 | Negative build thiếu key, positive build và SDK resolve + authorization smoke |

**Trạng thái tài liệu:** Plan đã xử lý review; các checkbox là công việc tương lai, chưa có xác nhận implementation/test/build T18.
