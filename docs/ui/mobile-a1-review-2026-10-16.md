# Review Mobile A1 — 16/10/2026

Phạm vi cố định: `git -C mobile diff 802fed7...5ae87e2`, gồm đúng 7 commit người dùng nêu. Working tree mobile sạch trước/sau review. Đối chiếu [plan](../superpowers/plans/2026-10-16-camera-mobile-a1.md), [spec](../superpowers/specs/2026-10-15-camera-mobile-a1-design.md), `mobile/AGENTS.md`, source backend hiện có và [báo cáo nghiệm thu](mobile-a1-verification.md). Không sửa implementation hoặc lịch sử commit.

**Kết luận:** Chưa đủ điều kiện xác nhận cả 7 task hoàn tất. Có 14 findings theo hai trục dưới đây: Standards 4, Spec 10. P1 là lỗi ảnh hưởng flow/dữ liệu/cấu hình an toàn cần sửa trước nghiệm thu; P2 là lỗi cần xử lý nhưng phạm vi hẹp hơn. Không tính lỗi lint hoặc code smell chỉ mang tính sở thích.

## Standards — 4 findings

### ST1 — P1: Storage chưa init và favorites chưa được load trong luồng app

**Quan sát tĩnh:** `mobile/lib/main.dart:49` chỉ init AppConfig; tìm trong `mobile/lib` không có lời gọi `StorageService.instance.init()`. StorageService giữ `_prefs` dạng late tại `mobile/lib/src/services/storage_service.dart:9`. `CameraScreen.initState()` (`mobile/lib/src/features/cameras/presentation/screens/camera_screen.dart:70`) chỉ tạo preview/catalog và subscribe `watch()`, không gọi repository.load(). `CameraFavoritesCubit.init()` có load nhưng không được tạo trong production.

**Hậu quả:** trên luồng boot hiện tại, ghi SharedPreferences gặp `_prefs` chưa init; lỗi trả về từ setSaved bị UI bỏ qua. Ngay cả khi bổ sung init, restart vẫn không nạp saved JSON; thêm mục mới từ cache rỗng có thể ghi đè dữ liệu cũ. Báo cáo “restart vẫn còn” chưa phù hợp source.

**Sửa:** init StorageService có xử lý failure; tạo một favorites repository/Cubit đúng scope, await load trước mutations, hiện lỗi ghi/hỏng dữ liệu và CTA reset chủ động. Thêm test production boot + saved JSON + restart, không chỉ test repository gọi load thủ công.

### ST2 — P1: ThumbnailScheduler/cache chưa được nối vào UI

**Quan sát tĩnh:** `mobile/lib/src/features/cameras/presentation/widgets/camera_tile.dart:36` chỉ nhận `assets/`; endpoint backend luôn render `assets/images/placeholder.jpg` tại dòng 47. Trong `mobile/lib/src/features/cameras` không có production construction/use của ThumbnailScheduler. `CameraScreen` tạo preview tại dòng 72 không inject cache; scheduler/cache mới có test và class definition.

**Hậu quả:** các camera thật trong list đều dùng ảnh placeholder, không phải snapshot tương ứng. Concurrency4/LRU8MiB/visible+prefetch không có hiệu lực trong app dù test class riêng pass.

**Sửa:** nối scheduler/window visibility/cache vào feature scope; render frame/request state từng ID, cancel offscreen/background và ưu tiên preview; kiểm tra request thật khi scroll và mode change. Tuân thủ requirement ảnh visible và no network trong widget.

### ST3 — P1: Ghi Quan tâm đồng thời làm mất mục

**Quan sát tĩnh + tái hiện bằng test:** `mobile/lib/src/features/cameras/data/repositories/local_favorites_repository.dart:68` copy cache trước `await _store.write()` tại dòng 93. Hai setSaved A/B đồng thời tính cùng base; completion sau thay toàn bộ state bằng B. Probe nhận `{B}` thay `{A,B}`. Test hiện tại tên serialized_toggles_survive_restart lại await từng thao tác, nên không kiểm tra serialize.

**Sửa:** serialize load/save/remove/reset; tính nextList bên trong queue và publish chỉ khi write thành công. Test hai write overlap và completion đảo thứ tự.

### ST4 — P2: Bỏ qua false của SharedPreferences

**Quan sát tĩnh:** `mobile/lib/src/features/cameras/data/datasources/favorites_local_store.dart:31` và `:40` map mọi Right<bool> thành Right(null), kể cả false. StorageService thực sự trả FutureEither<bool>.

**Hậu quả:** platform báo không ghi/xóa được vẫn được UI xem là thành công, không rollback theo spec. **Sửa:** false → DatabaseFailure; test storage adapter trả Right(false).

## Spec — 10 findings

### SP1 — P1: Client không tương thích backend đã chốt

**Quan sát tĩnh + hai probe tái hiện:** `mobile/lib/src/services/camera_api_client.dart:27` gửi `x-camera-reader-key` thay `x-api-key`; dòng 55 gọi `/api/v1/cameras` thay `/v1/cameras`; dòng 49 dùng `query` thay `q`, bỏ `provinceId=tp_hcm`. District path cũng sai (`/api/v1/cameras/districts` thay `/v1/camera-districts`). Config còn thêm header khác `x-reader-key`.

Backend xác nhận tại `backend/src/catalog/catalog.controller.ts:9`, `:34`, `backend/src/http/api-key.guard.ts:28`, query-schema. Backend trả `{data,meta}`; `mobile/lib/src/features/cameras/data/models/camera_dto.dart:73` đọc `items` và pagination ở root. Detail/playback cũng chưa unwrap data, capabilities.snapshot bị thay bằng snapshotCapable root.

**Hậu quả:** cấu hình backend đúng vẫn lỗi auth/route/query; nếu sửa routes/header riêng lẻ thì catalog trả 200 vẫn thành 0 camera, detail/playback parse sai. Fake tests đang tái tạo contract sai nên vẫn pass.

**Sửa:** sửa routes/auth/query/DTO envelope đồng bộ theo backend, giữ meta.dataMode/catalog/page; thêm contract tests lấy response fixture thật của backend và smoke Android/backend fixture. Không sửa backend để hợp thức hóa contract client tự đặt.

### SP2 — P1: Guard kiểm tra host chưa đủ origin và chưa chặn redirect

**Quan sát tĩnh + hai probe tái hiện:** `camera_api_client.dart:210` chỉ so Uri.host tại dòng 212; `http://example.test:8443/...` được gửi khi config là `https://example.test`, kèm reader header. Request options dòng 235 không disable redirects; probe xác nhận followRedirects=true. Đây là request qua adapter giả, chưa thực hiện chuyển key ra mạng.

**Hậu quả:** descriptor cùng host nhưng khác scheme/port vượt guard, trái yêu cầu relative/backend-only và có thể chuyển auth qua kết nối không mong muốn. **Sửa:** chỉ nhận relative endpoint hợp lệ, normalize/resolve rồi check scheme+host+port/userinfo, chặn redirect trước khi gửi key; áp dụng policy cho JSON và binary.

### SP3 — P1: Feature chưa render Liquid Glass surfaces

**Quan sát tĩnh:** main/App có initialize/wrap/theme, nhưng toàn `mobile/lib/src/features/cameras` không dùng widget từ liquid_glass_widgets. `camera_screen.dart:145` dùng Scaffold/AppBar thường; `camera_snapshot_sheet.dart:20` dùng showModalBottomSheet và dòng 95 dùng Container nền scaffold đặc. Filter cũng là widget Material thường.

**Hậu quả:** cấu hình theme/package không tự biến các surfaces này thành glass; không đạt style cốt lõi đã chốt. **Sửa:** dùng GlassScaffold/chrome/GlassModalSheet hoặc composition chính thức đúng1.13.0, giữ content/ảnh rõ; nghiệm thu shader bằng production App trên thiết bị.

### SP4 — P1: Background/resume vẫn nhận response trước background

**Quan sát tĩnh + probe fake transport:** `camera_preview_cubit.dart:242` cancel token nhưng không tăng generation. Completion tại dòng 122 set `_isInFlight=false` rồi chỉ check generation, không check owner/cancel/foreground. Probe cho request2 resume hoàn tất trước, request1 cũ hoàn tất sau: frame1 ghi đè frame2.

**Sửa:** epoch/request ownership riêng cho mỗi request/lifecycle transition; chỉ current owner được emit hoặc clear in-flight. Cancel là best effort, không thay generation guard. Test late successful completion sau cancel/background/resume. Spec §5 yêu cầu “vô hiệu hóa kết quả cũ bằng generation”.

### SP5 — P1: Đổi camera có thể hiển thị snapshot camera trước

**Quan sát tĩnh + probe:** `camera_preview_cubit.dart:46` không clear camera/descriptor; copyWith không có clear cho hai field. Khi mở A thành công rồi mở B và playback B lỗi, dòng79–83 vẫn fetch; dòng101 ưu tiên descriptor A. Probe xác nhận snapshot cuối vẫn `/.../A/snapshot` thay B.

**Sửa:** reset metadata/descriptor khi đổi ID, validate descriptor.cameraId, không fallback qua descriptor camera trước hoặc bỏ qua lỗi playback không retryable. Spec §5: không render ảnh A trong B.

### SP6 — P2: 304 thay thời điểm ảnh và luôn clear stale

**Quan sát tĩnh + probe:** `camera_preview_cubit.dart:178` tạo frame với fetchedAt=clock.now; dòng185 clear stale. Probe time12:00 →12:02 đổi fetchedAt dù bytes không đổi. Spec §5 yêu cầu giữ thời điểm ảnh cuối; report nghiệm thu lại mô tả cập nhật thời gian.

**Hậu quả:** liên tục304 che việc ảnh chưa cập nhật. **Sửa:** giữ frame timestamp, tách HTTP checkedAt nếu cần; tính stale cả khi304; không thêm text timestamp vào UI đã bỏ.

### SP7 — P2: Bằng chứng nghiệm thu vượt kiểm thử đang có

**Quan sát runtime:** analyze hiện tại0 issues, `flutter test`43 tests pass. Report ghi52 tests, bảng suite counts cũng không đủ làm bằng chứng runtime. APK debug171,773,504bytes tồn tại; review không rebuild/install APK.

**Quan sát tĩnh:** `mobile/integration_test/camera_flow_test.dart:104` viewer nằm trong `if(sheetImage.evaluate().isNotEmpty)`, thiếu ảnh vẫn bỏ qua flow và pass. Một số thao tác mode cũng optional. Test dùng MaterialApp/in-memory favorites, không production App/glass/storage; không rotate/restart/assert camera anchor. Không tìm thấy `evidence/mobile-a1/` cho screenshot/device/request lifecycle được plan yêu cầu.

**Sửa:** assertions bắt buộc; chạy shell/storage/backend fixture thực trên Android, lưu command/log/screenshot/SDK/device và checklist đúng status. Chưa có smoke thật/iOS thì ghi chưa xác minh, không “hoàn chỉnh12yêu cầu”.

### SP8 — P1: Phân trang nối thẳng, không dedupe/version guard

**Quan sát tĩnh:** `camera_catalog_cubit.dart:144` nối `[...state.items,...page.items]`, không merge theo ID hoặc so catalogVersion. State không giữ version của chain. `setQuery()` chỉ tăng generation sau debounce350ms, tạo cửa sổ response query cũ vẫn được nhận trước debounce kết thúc.

**Hậu quả:** catalog thay đổi/overlap trang tạo trùng camera hoặc trộn version; đang nhập query mới có thể bị response cũ ghi đè tạm thời. **Sửa:** invalidate generation ngay khi input đổi, debounce chỉ việc gửi; page merge theoID nhưng offset tăng theo raw records, đổi version restart trang0 theo spec. Test overlap/version/query trong debounce.

### SP9 — P2: 429 từ HTTP client không kích hoạt policy đã test

**Quan sát tĩnh + probe:** `camera_api_client.dart:348` retryable chỉ khi status≥500/connectionTimeout; Retry-After không parse. Vì429→retryablefalse, preview `_handleFailure` return trước nhánh429. Probe xác nhận retryablefalse và retryAfter thiếu. Unit Cubit test tạo ApiFailure retryabletrue bằng tay nên không phát hiện integration này.

**Sửa:** map429 có retry policy, parse Retry-After dạng seconds/date, giới hạn delay max(60s,header); giữ code/requestId/retryable của error contract; kiểm tra client→Cubit chain.

### SP10 — P2: Header bytes không đủ chứng minh ảnh decode được

**Quan sát tĩnh + probe:** `camera_api_client.dart:303` chấp nhận bất kỳ bytes bắt đầu FF D8; probe4bytes `[255,216,0,0]` được SnapshotReceived. RIFF bất kỳ cũng bị coi WebP; chưa validate MIME/decode trước thay last-good frame.

**Hậu quả:** payload lỗi/cụt có thể thay ảnh tốt trong cache/preview, rồi Image.memory báo decode error; spec yêu cầu giữ ảnh cũ khi refresh/decode lỗi. **Sửa:** validate MIME+actual decoder, dispose codec/resource, giữ last-good frame; stream vẫn phải giữ cap2MiB. Test ảnh thật, truncatedJPEG, RIFF không WebP, decodefailure sau ảnh tốt.

## Bằng chứng kiểm thử và giới hạn

- Chạy lại `D:/flutter/bin/flutter.bat analyze`: exit0, No issues found.
- Chạy lại `D:/flutter/bin/flutter.bat test --reporter compact`: exit0, **43 passed**. Có diagnostic decode marker với fixture nhưng suite vẫn pass; không coi đây là regression riêng khi chưa pin nguồn.
- [10 probe hồi quy](../../scripts/mobile/review_mobile_a1_test.dart), chạy từ mobile: `D:/flutter/bin/flutter.bat test ../scripts/mobile/review_mobile_a1_test.dart --reporter expanded`. Kết quả **0 pass/10fail**, exit1 như dự kiến: các assertion diễn tả hành vi đúng theo spec, fail tái hiện lỗi hiện tại. Script dùng adapter/fake, không credentials thật hoặc upstream request.
- [Log probe](../../evidence/mobile-a1-review/2026-10-16/regression-probes.log). Production mobile working tree vẫn sạch. Script/report nằm ngoài mobile repo; không commit/merge/push.
- Graph Tier2 `TTGT-Tphcm` generation2026-10-14 chỉ9nodes; search Camera/Thumbnail/Favorites/Snapshot không có symbol. Coverage từng file dựa kết luận đều not_tracked; đọc source/rg fallback, không dùng absence graph để chứng minh dead code. Không phát sinh REA/APK reverse evidence.
- Chưa chạy lại build APK, test trên emulator/điện thoại thật, backend network smoke hoặc iOS. Điều được tái hiện là hành vi class/transport qua test harness, không lời khẳng định đã quan sát app gốc hoặc traffic thực.

**Tổng:** Standards4 (nghiêm trọng nhất: favorites chưa khởi tạo/nạp dữ liệu); Spec10 (nghiêm trọng nhất: client không tương thích backend). Cần sửa rồi cập nhật kiểm thử và báo cáo nghiệm thu trước khi đánh dấu A1 hoàn tất.
