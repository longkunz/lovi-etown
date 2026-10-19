# Tech stack — bằng chứng ban đầu

Artifact và ID bằng chứng: xem [investigation.md](investigation.md). Mọi mục dưới đây là quan sát tĩnh trừ khi ghi runtime; mức sử dụng nghiệp vụ không suy ra chỉ từ plugin registration.

| Thành phần | Kết luận | Bằng chứng / giới hạn |
|---|---|---|
| UI và nghiệp vụ | Flutter, Dart AOT | Manifest `flutterEmbedding=2`; flutter_assets; libflutter.so và libapp.so; snapshot symbols `_kDartIsolateSnapshotInstructions`; package URI Dart của app trong E-05 |
| Android host | Java/Kotlin, R8-obfuscated | MainActivity.java:9–15, kiểm tra Kotlin Intrinsics và FlutterEngine; chưa xác nhận ngôn ngữ ban đầu của mọi file |
| Kiến trúc Dart | Có dấu hiệu MVP, repository, use case và injector | URI `core/mvp/base_ui_executor.dart`, `home_presenter.dart`, `app_repository.dart`, `app_use_case.dart`, `app/injector/*`; đây là suy luận từ tên, chưa phục hồi call chain |
| License gate | Pairip | Application.attachBaseContext gọi LicenseClient.checkLicense; runtime baseline chuyển tới LicenseActivity/Google Play, phiên có hook đi tiếp |
| HTTP Dart | package:http được đóng gói; có UdrivexApiClient | E-05 `package:http/src/io_client.dart` @415371, `UdrivexApiClient` @340032, client URI @784179; chưa xác minh mọi request đi qua client này |
| Snapshot TP.HCM | Catalog local mã hóa và image client | Asset tp_hcm.json.enc (1439794 bytes, magic CG01), giaothong_image_client.dart @693759, snapshot_http_image_viewer.dart @332639; UI runtime có ảnh thumbnail |
| Maps/location | Google Maps Flutter + Geolocator | GeneratedPluginRegistrant.java:58–66; manifest quyền coarse/fine; bản đồ và disclosure vị trí hiện runtime |
| Playback phổ thông | media_kit + libmpv | Registrant:94–101; split có libmpv.so và libmediakitandroidhelper.so; chưa chứng minh player cho mọi nguồn |
| Playback EVUP riêng | Flutter channel → native Kotlin/Java → WebSocket → parser/decode → MediaCodec Surface | MainActivity:14; p161w1/h.java:118–136, 149–218; p161w1/n.java:265–338, 670+; call path đọc từ mã, chưa áp dụng cho mọi camera |
| Lưu trữ | Favorites dùng SharedPreferences StringList; catalog có disk JSON và asset CG01 | Runtime XML xác nhận key camera_favorite_ids lưu id; asset/cache có 726 ID, xem catalog-cache-favorites.md. sqflite có đăng ký nhưng chưa gán tính năng |
| Monetization | AdMob, RevenueCat / Play Billing | Registrant:68–72,114–117; settings UI quảng bá VIP; logcat thấy open/inter/reward ad loaded; chưa xác minh giá/gói |
| Telemetry/config | Firebase Analytics, Crashlytics, Remote Config; Mixpanel | Registrant:33–54,104–107; runtime bắt được POST /track/ host api.mixpanel.com; không suy ra toàn bộ payload |
| Crypto | encrypt, cryptography có trong Dart AOT | E-05 URI thư viện; CatalogCrypto @460962; public.pem trong asset. Chưa xác minh thuật toán/key layout của catalog |

Đợt capture HTTP Dart đã xác định revision engine `3452d735bd38224ef2db85ca763d862d6326b17f`, có ở tag Flutter 3.41.0. Symbol archive chính thức khớp cả Build ID và `.text`; binary có version string Dart 3.11.0. Điều này xác định engine, không chứng minh version toàn bộ Flutter SDK/package của app. Chi tiết provenance ở [dart-network-findings.md](dart-network-findings.md).

Đã quan sát POST từ Dart tới năm API Udrivex và JPEG GET từ Notis; catalog TP.HCM response chứa 860 URL Notis và 40 URL HTTP khác. Mối quan hệ backend/live với catalog local mã hóa còn chưa chốt, không mặc định asset là nguồn chính.

Plugin phụ khác được đăng ký: device_info_plus, package_info_plus, share_plus, image_gallery_saver_plus, in_app_review, url_launcher, wakelock_plus, webview_flutter, jni/jni_flutter.

Phiên bản Android app: 2.0.0 / 202609282; minSdk 24, target/compile SDK 36. Chưa xác định toàn bộ package/version Dart. User-Agent Dart/3.12 là header khác version string engine, không dùng để suy ra SDK. Graph Java không thể dùng để trả lời caller trong Dart AOT.

## Điểm cần cải tiến khi thiết kế lại

Dart AOT đã được đọc thêm bằng DAE v0.1.13 x64. `AppCheckToken` dùng asset public key RSA; payload và ciphertext đã đối chiếu header runtime, xem [app-check-analysis.md](app-check-analysis.md). Không dùng profile SDK unverified của DAE để kết luận phiên bản runtime.

Nguồn `p161w1/n.java:154–222` chứa trust manager rỗng và hostname verifier cho các host vtscloud.vn/gov.vn cùng subdomain. Đây là quan sát mã tĩnh, chưa kiểm chứng MITM. App mới cần dùng xác thực TLS chuẩn và giải quyết chứng thư ở nguồn/backend thay vì sao chép cách nới trust này.
