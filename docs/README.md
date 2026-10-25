# Tài liệu Dự án Lovi Etown (Camera Giao thông TP.HCM)

Chào mừng đến với kho tài liệu phát triển của dự án **Lovi Etown**. Thư mục này tổng hợp toàn bộ tài liệu đặc tả, thiết kế kiến trúc, hợp đồng API, kế hoạch triển khai, tài sản UI/Stitch và báo cáo nghiệm thu được chuyển giao từ giai đoạn phân tích sang giai đoạn phát triển chính thức tại `D:\lovi-etown`.

Đọc [hiện trạng dự án](project-status.md) trước khi tiếp tục phát triển. Các spec/plan và nhật ký ngày 14–16/10 lưu cả trạng thái trước triển khai; dùng trang hiện trạng và báo cáo nghiệm thu để phân biệt phần đã làm với roadmap.

---

## 1. Cấu trúc Tài liệu & Bản đồ Tra cứu

```
docs/
├── README.md                           # Bản đồ tra cứu tài liệu (file này)
├── project-status.md                   # Hiện trạng, kiểm thử gần nhất và tài liệu lịch sử
├── agents/                             # Cấu hình tracker, nhãn triage và domain cho Matt Pocock Skills
├── rebuild-spec.md                     # Đặc tả cốt lõi xây dựng ứng dụng mới (11 yêu cầu R-01 -> R-11)
├── camera-spec.md                      # Đặc tả chức năng module Camera
├── api-catalog.md                      # Danh mục API nguồn & backend contract
├── data-model.md                       # Mô hình dữ liệu độc lập
├── tech-stack.md & stack-review.md     # Đánh giá và lựa chọn công nghệ
├── backend-reverse-traceability.md     # Ma trận truy vết từ yêu cầu sang Backend
├── feature-matrix.md & flows.md        # Ma trận tính năng và luồng tương tác người dùng
├── improvement-backlog.md              # Backlog các điểm cải tiến UX/kỹ thuật
│
├── superpowers/                        # Thiết kế chi tiết & Kế hoạch triển khai A1
│   ├── specs/
│   │   ├── 2026-10-14-camera-backend-design.md     # Thiết kế kiến trúc Backend NestJS
│   │   └── 2026-10-15-camera-mobile-a1-design.md  # Thiết kế Mobile Flutter A1 (Liquid Glass)
│   └── plans/
│       ├── 2026-10-14-camera-backend-a1.md        # Kế hoạch triển khai Backend A1
│       ├── 2026-10-16-camera-mobile-a1.md         # Kế hoạch triển khai Mobile A1 (7 Tasks)
│       └── 2026-10-14-android-reverse-and-rebuild.md
│
├── ui/                                 # Thiết kế giao diện & Báo cáo Mobile
│   ├── stitch-brief.md                 # Design Brief tạo giao diện trên Google Stitch
│   ├── mobile-a1-review-2026-10-16.md  # Báo cáo rà soát 14 findings (ST1-ST4, SP1-SP10)
│   ├── mobile-a1-verification.md       # Báo cáo nghiệm thu hoàn tất 45 tests & 10 probes
│   ├── t03-android-acceptance-2026-10-19.md  # Nghiệm thu T03 trên Android: bằng chứng từng phần + việc còn lại
│   └── stitch/                         # Mockup, HTML, screenshot, JSON screens từ Stitch
│       ├── README.md                   # Tổng kết artboards và các phiên bản UI
│       └── assets/, references/        # Snapshot gốc, ảnh tham chiếu và prototype
│
└── [Lịch sử Điều tra & REA Findings]   # Bằng chứng kỹ thuật từ phân tích tĩnh & runtime
    ├── investigation.md                # Nhật ký tổng hợp tiến độ điều tra (Pass 1 -> Pass 7)
    ├── camera-api-debug-pass7.md       # Phân tích runtime HTTP & relocation boundary
    ├── camera-contract-pass6.md        # Hợp đồng dữ liệu snapshot & nearby
    ├── camera-runtime-pass2..5.md      # Khảo sát runtime Android 9 & Android 13
    ├── app-check-analysis.md           # Phân tích App Check & cơ chế bảo vệ token
    └── dart-network-findings.md        # Khảo sát tầng mạng Dart/Flutter AOT
```

---

## 2. Các Tài liệu Trọng tâm Cần Đọc Khi Bắt Đầu

### 2.1. Về Yêu cầu & Kiến trúc Sản phẩm
- [rebuild-spec.md](rebuild-spec.md): Tài liệu nền tảng định nghĩa 11 yêu cầu chức năng (R-01 đến R-11), mô hình dữ liệu độc lập, hợp đồng backend cần có, và các tiêu chí nghiệm thu không phụ thuộc app cũ.
- [camera-spec.md](camera-spec.md): Đặc tả chi tiết về cách quản lý vòng đời camera, polling chu kỳ 12s, snapshot preview, cơ chế refresh và xử lý lỗi mạng.
- [data-model.md](data-model.md): Định nghĩa các thực thể `Camera`, `Snapshot`, `Favorite`, `Area`, `SelectedLocation`, `CameraPage`.

### 2.2. Về Backend (NestJS Service)
- [superpowers/specs/2026-10-14-camera-backend-design.md](superpowers/specs/2026-10-14-camera-backend-design.md): Kiến trúc dịch vụ REST API NestJS, phân vùng module (`catalog`, `snapshot`, `health`), bảo mật `x-api-key`, xử lý ETag 304, TTL in-memory cache và giới hạn rate limiting.
- [superpowers/plans/2026-10-14-camera-backend-a1.md](superpowers/plans/2026-10-14-camera-backend-a1.md): Kế hoạch và các bước dựng server, test fixture, và acceptance criteria.
- [backend/docs/verification.md](../backend/docs/verification.md): Báo cáo nghiệm thu tích hợp backend, kiểm chứng toàn diện các endpoint danh mục, snapshot và kiểm soát chuyển hướng an toàn.
- [deploy/README.md](../deploy/README.md): Runbook triển khai bản dùng thử T08 theo spec T06 (một VPS + Docker Compose + Caddy HTTPS, backup/khôi phục, kiểm tải D7) — bộ triển khai sẵn sàng, chưa triển khai thật.

### 2.3. Về Mobile (Flutter App)
- [superpowers/specs/2026-10-15-camera-mobile-a1-design.md](superpowers/specs/2026-10-15-camera-mobile-a1-design.md): Đặc tả thiết kế Mobile A1:
  - Một màn hình Camera chính tích hợp mục Quan tâm inline (collapsible / bộ lọc).
  - Modal Bottom Sheet tối giản mở khi chọn camera (giữ nguyên tỷ lệ ảnh JPEG, không crop).
  - Trình xem ảnh tương tác toàn màn hình (InteractiveViewer, xoay ngang tự động, pinch-to-zoom 1–5x, double-tap).
  - Phong cách Liquid Glass sử dụng package `liquid_glass_widgets: 1.13.0`.
- [superpowers/plans/2026-10-16-camera-mobile-a1.md](superpowers/plans/2026-10-16-camera-mobile-a1.md): Kế hoạch 7 tác vụ xây dựng BLoC/Cubit, Repository, Scheduler thumbnail, và bộ widget.
- [superpowers/specs/2026-10-19-trial-access-operations-spec.md](superpowers/specs/2026-10-19-trial-access-operations-spec.md): Đặc tả T06 (đã chốt 2026-10-19): hợp đồng truy cập bản dùng thử (reader key chung + rate limit 120/phút/IP, xoay key có cửa sổ chồng lấp 7 ngày, màn hình "cần cập nhật app" khi 401/403) và vận hành (một VPS + Docker Compose + Caddy, nhóm kín ~20 người, tải mục tiêu 20 người xem đồng thời với p95 snapshot < 500 ms, log 7 ngày/backup 3 bản) — căn cứ triển khai T07/T08.
- [superpowers/specs/2026-10-20-p0-p1-feature-backlog-spec.md](superpowers/specs/2026-10-20-p0-p1-feature-backlog-spec.md): Đặc tả lộ trình tính năng P0/P1 sau A1 (đã duyệt 2026-10-20): rút ra từ reverse-engineering Traffic Camera VN 9.21.1 và kiểm chứng trực tiếp trên Notis — Notis có sẵn HLS `videoUrl` ở 28/504 camera nhưng Lovi đang hardcode `live: false`; 9 quyết định D1–D9 (kiểm chứng HLS, nút chỉ đường, nhóm quận + thời tiết, lưới đa camera, mở rộng vùng phủ, live HLS, widget Android, thông báo theo camera, traffic brief) làm căn cứ cho các ticket T09–T17.
- [superpowers/specs/2026-10-24-camera-google-maps-traffic-design.md](superpowers/specs/2026-10-24-camera-google-maps-traffic-design.md): Đặc tả T18 — Tích hợp Google Maps & Lớp Giao thông Kẹt xe (Traffic Layer) vào Chi tiết Camera (dựa trên reverse-engineering VietDi 5.4.6).
- [superpowers/plans/2026-10-24-camera-google-maps-traffic.md](superpowers/plans/2026-10-24-camera-google-maps-traffic.md): Kế hoạch triển khai T18 gồm 6 task xây dựng widget bản đồ mini Liquid Glass, lớp giao thông thời gian thực, viewer toàn màn hình và kiểm thử tự động.
- [superpowers/specs/2026-10-24-liquid-glass-refresh-design.md](superpowers/specs/2026-10-24-liquid-glass-refresh-design.md): Đặc tả thiết kế Liquid Glass Refresh — Chuẩn hóa trải nghiệm thị giác, độ mờ có chiều sâu, tương phản cao, và khả năng tiếp cận (touch target ≥ 48×48 px) xuyên suốt toàn bộ app.
- [superpowers/plans/2026-10-24-liquid-glass-refresh.md](superpowers/plans/2026-10-24-liquid-glass-refresh.md): Kế hoạch thực thi 6 tác vụ refresh giao diện Liquid Glass.
- [ui/liquid-glass-refresh-verification.md](ui/liquid-glass-refresh-verification.md): Báo cáo nghiệm thu Liquid Glass Refresh (165/165 tests Flutter PASS, 86/86 tests Backend PASS, 12 mockup PNG review, đạt AC1–AC8).
- [ui/mobile-a1-verification.md](ui/mobile-a1-verification.md): Nghiệm thu 14 findings kỹ thuật (khóa đồng bộ Mutex lưu Quan tâm, chống rò rỉ token qua chuyển hướng, quản lý generation token khi vào background, v.v.).

---

- [ui/camera-map-discovery-verification.md](ui/camera-map-discovery-verification.md): #40 — Bản đồ mặc định/Vietmap/Gần tôi, API PostGIS, automated checks, build Android/iOS và Android demo smoke; nghiệm thu native với key thật còn thiếu.

## 3. Quy tắc Dành cho Nhà phát triển Tiếp nối

1. **Độc lập dữ liệu:** Không gọi trực tiếp upstream API gốc từ client. Tất cả giao tiếp qua Backend proxy NestJS (`/v1/...`).
2. **Bảo mật:** Không hardcode API key, không commit file `.env`. Client chỉ dùng `x-api-key` dạng reader công khai được cấp phép.
3. **Quản lý state & Lifecycle:** Mọi luồng polling ảnh phải tự hủy khi widget unmount, modal đóng hoặc app vào background để tiết kiệm tài nguyên.
4. **Kiểm thử trước khi commit mã nguồn:** Chạy lần lượt `npm run test:unit`, `npm run test:api`, `npm run test:db` ở `backend/` và `flutter test` ở `mobile/`. Chuẩn bị PostgreSQL/PostGIS theo [hướng dẫn backend](../backend/README.md) trước các suite API/database.
