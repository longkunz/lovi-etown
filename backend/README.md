# Camera Backend A1 — Ho Chi Minh City Traffic Camera Service

Camera Backend A1 là service backend Node.js 24 LTS + NestJS 12 (ESM) + Fastify cung cấp danh mục camera giao thông TP.HCM, tìm kiếm theo tên/địa chỉ/quận huyện (chuẩn hóa không dấu), playback descriptor và pipeline proxy snapshot có bộ đệm (bounded cache), chống quá tải upstream (in-flight coalescing & fetch pool), và hủy an toàn (cancellation).

---

## 1. Công nghệ & Kiến trúc

- **Runtime & Ngôn ngữ:** Node.js 24 LTS, TypeScript 6 (strict mode, pure ESM).
- **Framework:** NestJS 12 trên nền Fastify adapter (high-performance HTTP).
- **Cơ sở dữ liệu:** PostgreSQL 17 + PostGIS 3.5, lưu trữ tọa độ spatial `geography(Point, 4326)` và chỉ mục search không dấu.
- **Bảo mật & Rate Limit:**
  - Token phân quyền `x-api-key`: Reader key (`BACKEND_API_KEY`) và Admin key (`ADMIN_API_KEY`).
  - Rate limiting theo sliding window (mặc định 120 req/min).
  - Giới hạn body (64 KiB), kích thước ảnh snapshot (2 MiB).
  - Lọc log an toàn: không ghi token, header nhạy cảm, query string hoặc body.
- **Khả năng phục hồi upstream (Notis Provider):**
  - Lock đồng bộ PG session advisory lock (`17001401`) ngăn sync đồng thời (409 `SYNC_IN_PROGRESS`).
  - Cache snapshot trong bộ nhớ tối đa 32 MiB, TTL 3000ms, hỗ trợ HTTP ETag / 304 `Not Modified`.
  - Giới hạn kết nối đồng thời: tối đa 4 upstream fetch song song, 32 vị trí xếp hàng (503 `BUSY`).
  - Coalescing: Gộp nhiều request cùng camera ID vào 1 upstream fetch duy nhất; tự động abort khi client hủy kết nối.
- **Tính độc lập:** Không phụ thuộc runtime vào Vietmap, Udrivex hay AppCheck.

---

## 2. Cài đặt & Khởi chạy Nhanh

### Yêu cầu hệ thống
- Docker & Docker Compose
- Node.js 24+ & npm (nếu chạy local)

### Bước 1: Thiết lập môi trường
Tạo file `.env` từ `.env.example`:
```bash
cp .env.example .env
```

### Bước 2: Chạy Database với Docker Compose
```bash
docker compose -f compose.test.yml up -d
```
Database kiểm thử PostGIS sẽ sẵn sàng tại `127.0.0.1:5433`.

### Bước 3: Chạy Migration cơ sở dữ liệu
```bash
npm run db:migrate
```

### Bước 4: Đồng bộ danh mục camera
- **Cách 1: Nạp bộ fixture mẫu (offline/demo):**
  ```bash
  npm run seed:fixture
  ```
- **Cách 2: Đồng bộ thực tế từ Notis API (bounding box trung tâm TP.HCM):**
  ```bash
  npm run camera:sync -- --bbox=106.60,10.70,106.80,10.85
  ```

### Bước 5: Khởi động server
```bash
npm run dev
# Hoặc chế độ production build:
npm run build && npm start
```
Server lắng nghe tại `http://127.0.0.1:3000`.

---

## 3. Tài liệu OpenAPI / Swagger

- Swagger UI: `http://127.0.0.1:3000/docs`
- OpenAPI 3.0 JSON Spec: `http://127.0.0.1:3000/docs-json`

---

## 4. Hướng dẫn Gọi API (cURL & PowerShell)

### Health Check (Public, không cần API Key)
```bash
# Kiểm tra liveness
curl http://127.0.0.1:3000/health/live

# Kiểm tra readiness (kết nối DB)
curl http://127.0.0.1:3000/health/ready
```

### Danh mục Camera (GET /v1/cameras)
```bash
curl -H "x-api-key: test-reader-key-32charslong!!" \
  "http://127.0.0.1:3000/v1/cameras?provinceId=tp_hcm&q=Nguyen&limit=10"
```
*PowerShell:*
```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:3000/v1/cameras?provinceId=tp_hcm&q=Nguyen&limit=10" -Headers @{ "x-api-key" = "test-reader-key-32charslong!!" }
```

### Thống kê Quận/Huyện (GET /v1/camera-districts)
```bash
curl -H "x-api-key: test-reader-key-32charslong!!" \
  "http://127.0.0.1:3000/v1/camera-districts?provinceId=tp_hcm"
```

### Chi tiết Camera (GET /v1/cameras/:id)
```bash
curl -H "x-api-key: test-reader-key-32charslong!!" \
  "http://127.0.0.1:3000/v1/cameras/<CAMERA_UUID>"
```

### Playback Descriptor (GET /v1/cameras/:id/playback)
```bash
curl -H "x-api-key: test-reader-key-32charslong!!" \
  "http://127.0.0.1:3000/v1/cameras/<CAMERA_UUID>/playback"
```

### Tải Ảnh Snapshot (GET /v1/cameras/:id/snapshot)
```bash
# Lần đầu: Trả về 200 OK kèm ảnh và ETag
curl -i -H "x-api-key: test-reader-key-32charslong!!" \
  "http://127.0.0.1:3000/v1/cameras/<CAMERA_UUID>/snapshot"

# Lần sau kèm If-None-Match: Trả về 304 Not Modified không tốn băng thông
curl -i -H "x-api-key: test-reader-key-32charslong!!" \
  -H 'If-None-Match: "<ETAG_VALUE>"' \
  "http://127.0.0.1:3000/v1/cameras/<CAMERA_UUID>/snapshot"
```

### Admin Đồng bộ Thủ công (POST /v1/admin/camera-providers/notis/sync)
```bash
curl -X POST http://127.0.0.1:3000/v1/admin/camera-providers/notis/sync \
  -H "x-api-key: test-admin-key-32charslong!!" \
  -H "Content-Type: application/json" \
  -d '{"provinceId":"tp_hcm","bbox":[106.69,10.76,106.71,10.78]}'
```

---

## 5. Kiểm thử & Vận hành

### Chạy Bộ Kiểm thử Toàn diện
```bash
# Typecheck TypeScript
npm run typecheck

# Unit tests
npm run test:unit

# API integration tests (HTTP boundary, camera APIs, snapshot pipeline, OpenAPI, E2E)
npm run test:api

# Database integration tests (Repository, migrations idempotency, advisory locks)
npm run test:db
```

### Bounded Smoke Test với Notis Real-Source
Chạy smoke test trên viewport thu hẹp của trung tâm TP.HCM:
```bash
npm run smoke:notis -- --bbox=106.695,10.770,106.705,10.780
```

### Sao lưu & Phục hồi Cơ sở Dữ liệu
Sử dụng công cụ tiêu chuẩn PostgreSQL an toàn thông tin đăng nhập:
```bash
# Sao lưu schema và dữ liệu
docker exec -t backend-db-1 pg_dump -U postgres -d camera_catalog_test -F c -b -v -f /tmp/backup.dump
docker cp backend-db-1:/tmp/backup.dump ./backup.dump

# Phục hồi vào database mới
docker cp ./backup.dump backend-db-1:/tmp/backup.dump
docker exec -t backend-db-1 pg_restore -U postgres -d camera_catalog_test -c -v /tmp/backup.dump
```

---

## 6. Giới hạn Phạm vi Slice A1 & Lưu ý Vận hành

1. **Phạm vi tính năng:** Slice A1 ưu tiên camera-first snapshot và danh mục tra cứu nhanh. Tính năng live video streaming (HLS/WebRTC), video recording hoặc bản đồ tương tác phức tạp được thiết kế cho các slice kế tiếp (A2+).
2. **Nguồn dữ liệu:** Đồng bộ định kỳ sử dụng Notis Public Provider với bbox bounding box. Khi upstream thay đổi cấu trúc hoặc gặp sự cố, hệ thống giữ nguyên danh mục hiện có và ghi nhận trạng thái `isStale` trung thực trong metadata phản hồi.
3. **Môi trường triển khai:** Thiết kế đơn giản hóa cho cụm đơn (single-VPS) sử dụng PostgreSQL Advisory Lock cho đồng bộ hóa tác vụ nền mà không cần thêm Redis.
