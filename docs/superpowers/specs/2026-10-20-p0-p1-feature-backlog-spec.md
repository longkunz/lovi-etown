# Đặc tả — Lộ trình tính năng P0/P1 sau A1 (từ reverse-engineering Traffic Camera VN)

Trạng thái: **ĐỀ XUẤT — chờ duyệt qua PR chứa đặc tả này.** Các quyết định D1–D9 dưới đây là đề xuất của agent dựa trên bằng chứng đã kiểm chứng; chỉ triển khai sau khi PR được merge (theo đúng tiền lệ T06 → T07/T08).

## Bối cảnh và bằng chứng

Ngày 2026-10-20, theo yêu cầu của Long, agent đã reverse-engineer app **Traffic Camera VN 9.21.1** (`com.freeapp.camtraffic.traffic_cam`, Flutter) bằng REA — bản đầy đủ lưu ngoài repo tại `~/workspace/user/traffic-cam-vn/` (`rea-report-chi-tiet.md`, `p0-p1-dao-sau.md`). Các phát hiện đã kiểm chứng trực tiếp trên code Lovi và API Notis, làm căn cứ cho đặc tả này:

1. **Notis có sẵn luồng live HLS.** Payload gốc `GET /v4/cameras/bybbox` chứa field `videoUrl` (m3u8) ở **28/504 camera toàn TP.HCM (5,6%)**, host tại `camera.thongtingiaothong.vn` (cổng giao thông chính thức) và một media server riêng. Provider của Lovi (`backend/src/providers/notis.provider.ts`) bỏ qua field này; `catalog.repository.ts` hardcode `capabilities.live: false` khi import — trong khi kiểu dữ liệu đã có sẵn `sourceKind: 'hls'` và `capabilities: { snapshot, live }`.
2. **Snapshot Notis tươi ≤ 20 giây** (hai lần lấy cách 20 s cho ảnh khác nhau, 512×288, ~55 KB) — đủ làm "live dạng ảnh".
3. **Nền lưới đa camera đã có sẵn:** mobile có `thumbnail_scheduler.dart`, `snapshot_memory_cache.dart`, polling 12 s có quản lý vòng đời trong `CameraPreviewCubit`, danh sách Quan tâm (favorites, local); backend có snapshot cache (TTL cấu hình, mặc định 3 s, 32 MiB) + fetch-pool chống nhân tải upstream.
4. **Hạ tầng push hiện bằng 0:** không Firebase/FCM ở cả mobile và backend.
5. **Việc rẻ đang chờ sẵn:** `url_launcher` + `geolocator` đã có trong `mobile/pubspec.yaml`; endpoint `/v1/camera-districts` đã tồn tại nhưng `district` đang null vì provider không map field `dist` của Notis (vd `"Quận 3"`).
6. **Chưa kiểm chứng được từ mạng sandbox:** phát thử playlist HLS đều thất bại (HTTP 000 ở cả 2 host) — cần phát lại từ VPS/mạng VN; scheme deep-link của Vietmap chưa xác minh.

## Nguyên tắc

- Giữ nguyên các quyết định T06: không đăng nhập, reader key chung + admin key riêng, rate limit 120/phút/key+IP, nhóm kín ~20 người.
- Không lộ thông tin upstream nhạy cảm ra app — đặc biệt field `values.ip` (IP nội bộ camera) trong payload Notis **không bao giờ** được lưu hay trả về. URL HLS là hạ tầng công cộng của thành phố, không chứa token, nên được trả thẳng cho app (không proxy video qua VPS — xem D6).
- Mọi kết luận kỹ thuật dựa trên bằng chứng kiểm thử thực tế (theo AGENTS.md): mỗi ticket có tiêu chí nghiệm thu và bộ test tương ứng (backend: unit/api/db; mobile: flutter test).
- Làm theo thứ tự phụ thuộc ở cuối đặc tả; không bắt đầu ticket khi điều kiện tiên quyết của nó chưa xong.

## Các quyết định đề xuất

### D1 — Kiểm chứng HLS và scheme Vietmap trên mạng VN (ticket T09, việc của người)
Phát thử ≥ 3 playlist `videoUrl` (cả 2 host) từ VPS hoặc thiết bị trên mạng VN trong cùng phiên thiết bị với #3/#5 và đo lại D7; xác minh scheme/URL mở app Vietmap Live. Kết quả quyết định phạm vi thật của D6. Không có code.

### D2 — Nút "Chỉ đường" tại màn hình xem camera (ticket T10, P1)
Trong bottom sheet/viewer của camera, thêm nút mở dẫn đường: ưu tiên Google Maps (`https://www.google.com/maps/dir/?api=1&destination=<lat>,<lng>` qua `url_launcher`), fallback `geo:` URI; thêm lựa chọn Vietmap sau khi D1 xác minh được scheme. Camera thiếu tọa độ thì ẩn nút. Không cần thay đổi backend.

### D3 — Nhóm theo quận + thẻ thời tiết (ticket T11, P1)
- Backend: provider map thêm field `dist` của Notis vào `district` **với vai trò nhãn hiển thị** (không phải dữ kiện hành chính chính thức — ghi rõ trong code comment và ADR nếu cần); migration/import lại catalog để lấp đầy quận.
- Mobile: nhóm/lọc danh sách theo quận dùng endpoint `/v1/camera-districts` sẵn có; đầu danh sách có thẻ thời tiết TP.HCM lấy từ **Open-Meteo** (miễn phí, không cần key), cache phía app, lỗi thời tiết không chặn danh sách camera.

### D4 — Lưới đa camera (ticket T12, P0)
Màn hình "Xem nhiều camera": lưới 2×2, tối đa 4–6 ô, nguồn từ danh sách Quan tâm + chọn thêm; mỗi ô poll snapshot 15–20 s qua `thumbnail_scheduler` hiện có, pause khi ô khuất/app background, giữ last-good frame + cờ stale theo pattern T02; chạm 1 ô mở viewer hiện tại (camera có live thì vào player của D6). Không phát video trong lưới.

### D5 — Mở rộng vùng phủ catalog (ticket T13, P0 — điều kiện cho D6 có ý nghĩa)
Mở bbox đồng bộ từ cửa sổ trung tâm hiện tại ra toàn TP.HCM (504 camera theo đo thực tế), giữ cơ chế sync/import hiện tại; kiểm tra lại dung lượng DB, thời gian sync và tải snapshot sau khi mở. Đây là quyết định sản phẩm (app chuyển từ "trung tâm" sang "toàn thành phố") — cần Long duyệt rõ trong PR này.

### D6 — Live HLS cho camera có `videoUrl` (ticket T14, P0)
Điều kiện tiên quyết: D1 xác minh phát được, D5 mở vùng phủ.
- Backend: `ProviderCamera` thêm `streamUrl?: string | null`; provider Notis map từ `videoUrl`; import đặt `capabilities.live = !!streamUrl`; API detail trả `streamUrl` khi `live = true`. Vẫn giữ đường snapshot cho mọi camera.
- Mobile: thêm `video_player` (ExoPlayer) — chỉ phát ở màn hình chi tiết, badge "LIVE" phân biệt với ảnh tĩnh, tự quay lại snapshot khi stream lỗi. Không proxy luồng qua backend.

### D7 — Widget màn hình chính Android (ticket T15, P0)
Widget hiển thị snapshot mới nhất + tên + giờ chụp của 1 camera Quan tâm chọn trước; chạm widget mở app vào đúng camera. Dùng gói `home_widget`, làm mới nền ~30 phút theo giới hạn OS. **Cần ngoại lệ native** (layout Android XML) như tiền lệ PR #17 — ghi rõ trong PR triển khai. iOS WidgetKit ngoài phạm vi đợt 1.

### D8 — Thông báo theo camera (ticket T16, P0 — làm sau cùng)
Điều kiện tiên quyết: Long duyệt lập project Firebase (việc mới cả 2 phía).
- Mô hình không-login: **FCM topics theo camera** (`cam_<cameraId>`), app subscribe topic của các camera Quan tâm; backend không lưu token người dùng.
- Kích hoạt đợt 1: thay đổi trạng thái availability (offline/online trở lại) do một prober chạy nền trên backend kiểm tra định kỳ, + bản tin theo lịch (digest sáng) cho camera Quan tâm. Không hứa cảnh báo ùn tắc (chưa có dữ kiện).
- Cần migration bảng trạng thái gửi thông báo để chống spam (chỉ gửi khi trạng thái đổi, có thời gian im lặng tối thiểu).

### D9 — Traffic brief v1: thẻ "Tình trạng tại điểm" (ticket T17, P1)
Trong viewer, thêm thẻ tổng hợp từ dữ kiện sẵn có: trạng thái availability, độ tươi của ảnh (giây kể từ ảnh mới nhất), số camera lân cận cùng quận đang online/tổng số, link "Chỉ đường" của D2. Không dùng AI/phân tích ảnh ở v1.

## Thứ tự và phụ thuộc

| Thứ tự | Ticket | Hạng mục | Phụ thuộc |
|---|---|---|---|
| 0 | T09 | Kiểm chứng HLS + Vietmap (phiên thiết bị) | — (việc của người) |
| 1 | T10 | Nút Chỉ đường | (Vietmap chờ T09, Google Maps làm ngay) |
| 1 | T11 | Nhóm quận + thẻ thời tiết | — |
| 2 | T12 | Lưới đa camera | — |
| 3 | T13 | Mở rộng vùng phủ catalog | Duyệt D5 trong PR này |
| 4 | T14 | Live HLS | T09 đạt + T13 |
| 5 | T15 | Widget Android | — (ngoại lệ native theo D7) |
| 6 | T17 | Traffic brief v1 | T11 (dữ kiện quận) |
| 7 | T16 | Thông báo theo camera | Duyệt lập Firebase (D8) |

## Ngoài phạm vi đợt này

- Các module super-app của đối thủ (giá vàng, giá xăng, tra phạt nguội, cứu hộ, đỗ xe/trạm sạc, tour, tin tức, referral, gói VIP).
- Trợ lý lái xe kiểu VietDi (cảnh báo biển báo/tốc độ, HUD, PiP khi lái, crowdsourcing báo cáo giao thông) — là một sản phẩm thứ hai, cần đặc tả riêng nếu Long muốn đi hướng đó.
- Phân tích ảnh suy luận ùn tắc; điều khiển PTZ; widget iOS; Firebase App Check cho API của Lovi (đã ghi nhận khác biệt với đối thủ, không làm đợt này).

## Câu hỏi mở cần Long quyết khi review PR

1. **D5:** duyệt mở vùng phủ ra toàn TP.HCM (504 camera) hay giữ trung tâm và chỉ bật live cho số ít camera hiện có?
2. **D7:** duyệt ngoại lệ code native cho widget Android?
3. **D8:** duyệt lập project Firebase phục vụ thông báo (T16), hay hoãn T16 vô thời hạn sau trial?
4. **D3:** chấp nhận dùng field `dist` của Notis làm nhãn hiển thị quận (không phải dữ kiện hành chính chính thức)?
