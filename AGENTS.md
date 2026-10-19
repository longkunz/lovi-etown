# Hướng dẫn Phát triển & Nguyên tắc Làm việc (Lovi Etown)

Tài liệu này định hình ngữ cảnh, kiến trúc và quy chuẩn phát triển cho toàn bộ AI coding assistants và lập trình viên làm việc tại workspace `D:\lovi-etown`.

---

## 1. Tổng quan Dự án & Mục tiêu

`D:\lovi-etown` là repository chính phát triển sản phẩm ứng dụng theo dõi camera giao thông (bắt đầu tại TP.HCM). 
Sản phẩm bao gồm:
1. **`backend/`**: REST API Proxy & Cache Service (NestJS, TypeScript).
2. **`mobile/`**: Ứng dụng di động đa nền tảng Android & iOS (Flutter, BLoC, Liquid Glass).
3. **`docs/`**: Toàn bộ hệ thống tài liệu đặc tả kỹ thuật, hợp đồng API, thiết kế UI và kết quả nghiệm thu.
4. **`scripts/`**: Các tiện ích kiểm thử, review và giả lập prototype.

---

## 2. Công cụ Codebase Memory MCP

- Dự án đã được đánh chỉ mục trong `codebase-memory-mcp` với định danh project: **`D-lovi-etown`**.
- **BẮT BUỘC** dùng `codebase-memory-mcp` (`search_graph`, `trace_path`, `get_code_snippet`, `check_index_coverage`) trước khi tìm kiếm, đọc, sửa đổi hoặc refactor mã nguồn.
- Chỉ dùng grep/glob cho các chuỗi literal, cấu hình môi trường hoặc file tài liệu ngoài mã nguồn.

---

## 3. Kiến trúc & Phân vùng Trách nhiệm

### 3.1. Phân vùng Backend (`backend/`)
- Quản lý danh mục camera theo tỉnh/thành (`/v1/cameras`, `/v1/camera-districts`).
- Cung cấp proxy snapshot JPEG an toàn (`/v1/cameras/:id/snapshot`), che giấu hoàn toàn token/IP máy chủ upstream.
- Hỗ trợ ETag và mã trạng thái 304 Not Modified để tối ưu băng thông.
- Kiểm soát truy cập thông qua header `x-api-key`.
- Khi bổ sung tính năng backend, phải bổ sung unit test/e2e test tương ứng trong `test/`.

### 3.2. Phân vùng Mobile (`mobile/`)
- Tuân thủ kiến trúc **Feature-first**: toàn bộ logic camera nằm trong `lib/src/features/cameras/`.
- **State Management:**
  - `CameraCatalogCubit`: Quản lý danh sách, tìm kiếm, phân trang và generation token chống response cũ.
  - `CameraPreviewCubit`: Quản lý việc xem camera, polling chu kỳ 12s, xử lý vòng đời foreground/background.
  - `CameraFavoritesCubit`: Quản lý danh sách yêu thích inline qua hàng đợi Mutex tuần tự hóa tuyệt đối.
- **Giao diện người dùng:**
  - Thiết kế một màn hình chính (`CameraScreen`), tích hợp danh mục Quan tâm inline (collapsible / bộ lọc).
  - Modal bottom sheet tối giản mở khi chọn camera.
  - Trình xem ảnh toàn màn hình overlay hỗ trợ xoay ngang tự động và zoom tương tác 1–5x (`CameraImageViewer`).
  - Áp dụng phong cách Liquid Glass từ package `liquid_glass_widgets: 1.13.0`.
- Tuyệt đối không gọi trực tiếp các dịch vụ upstream ngoài backend proxy.

---

## 4. Quy chuẩn Kiểm thử & Nghiệm thu

- Sau bất kỳ thay đổi nào trên mã nguồn:
  - Backend: Chạy `npm test` bên trong `backend/` và bảo đảm tất cả test suite đều PASS.
  - Mobile: Chạy `flutter test` bên trong `mobile/` và bảo đảm toàn bộ 45 unit/widget tests đều PASS.
- Mọi kết luận kỹ thuật phải dựa trên bằng chứng kiểm thử thực tế (evidence before assertion).

---

## 5. Tham chiếu Tài liệu

- Danh mục tài liệu đầy đủ: [`docs/README.md`](docs/README.md)
- Đặc tả xây dựng ứng dụng mới: [`docs/rebuild-spec.md`](docs/rebuild-spec.md)
- Thiết kế Mobile A1: [`docs/superpowers/specs/2026-10-15-camera-mobile-a1-design.md`](docs/superpowers/specs/2026-10-15-camera-mobile-a1-design.md)
- Kế hoạch triển khai Mobile A1: [`docs/superpowers/plans/2026-10-16-camera-mobile-a1.md`](docs/superpowers/plans/2026-10-16-camera-mobile-a1.md)
- Báo cáo nghiệm thu Mobile A1: [`docs/ui/mobile-a1-verification.md`](docs/ui/mobile-a1-verification.md)

## Agent skills

### Issue tracker

Track issues and specs in GitHub Issues for `longkunz/lovi-etown`. Before reading or publishing tickets, read `docs/agents/issue-tracker.md`.

### Triage labels

Use the five default triage labels. Before applying triage labels, read `docs/agents/triage-labels.md`.

### Domain docs

Use a single-context layout: root `CONTEXT.md` and `docs/adr/`. Before domain exploration, read `docs/agents/domain.md`.
