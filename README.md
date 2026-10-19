# Lovi Etown — Ứng dụng Camera Giao Thông

Dự án phát triển ứng dụng theo dõi và kiểm tra camera giao thông TP.HCM độc lập, hiện đại với giao diện Liquid Glass mượt mà trên nền tảng Flutter và hạ tầng Backend NestJS hiệu năng cao.

---

## 1. Cấu trúc Dự án

```
lovi-etown/
├── backend/            # Dịch vụ Backend NestJS (TypeScript, Fastify/Express, Docker)
├── mobile/             # Ứng dụng Flutter Android & iOS (BLoC, Liquid Glass UI)
├── docs/               # Toàn bộ tài liệu đặc tả, thiết kế kiến trúc, API và nghiệm thu
│   └── README.md       # Bản đồ tra cứu chi tiết toàn bộ tài liệu
└── scripts/            # Script kiểm thử, prototype giao diện và công cụ chẩn đoán
```

---

## 2. Công nghệ Cốt lõi

- **Mobile:**
  - **Framework:** Flutter (hỗ trợ Android & iOS)
  - **State Management:** BLoC / Cubit (`flutter_bloc: ^8.1.6`)
  - **Giao diện:** Liquid Glass (`liquid_glass_widgets: 1.13.0`)
  - **Mạng & Lưu trữ:** Dio, SharedPreferences (đồng bộ Mutex tuần tự hóa ghi dữ liệu)
  - **Kiến trúc:** Feature-first (`lib/src/features/cameras`)

- **Backend:**
  - **Framework:** NestJS (TypeScript)
  - **Tính năng:** Proxy snapshot, cache thông minh ETag 304, rate limiting, bảo vệ endpoint bằng `x-api-key`
  - **Container:** Docker & Docker Compose (`compose.yml`)

---

## 3. Bắt đầu Nhanh

### 3.1. Chạy Backend (`backend/`)

```bash
cd backend

# Cài đặt dependency
npm install

# Kiểm tra unit test & e2e test
npm test

# Chạy ở chế độ phát triển
npm run start:dev

# Hoặc khởi chạy qua Docker
docker compose up -d
```

Backend lắng nghe mặc định tại `http://localhost:3000`.

### 3.2. Chạy Mobile App (`mobile/`)

```bash
cd mobile

# Cài đặt các gói Flutter
flutter pub get

# Chạy toàn bộ bộ kiểm thử (45 tests)
flutter test

# Khởi chạy ứng dụng trên thiết bị/giả lập
flutter run
```

---

## 4. Tài liệu & Đặc tả Kỹ thuật

Tất cả tài liệu kỹ thuật, đặc tả và kết quả nghiệm thu được lưu trữ trong thư mục [`docs/`](docs/README.md):

- **Đặc tả Sản phẩm & Yêu cầu:** [`docs/rebuild-spec.md`](docs/rebuild-spec.md)
- **Đặc tả Module Camera:** [`docs/camera-spec.md`](docs/camera-spec.md)
- **Danh mục API & Contract:** [`docs/api-catalog.md`](docs/api-catalog.md)
- **Thiết kế Backend A1:** [`docs/superpowers/specs/2026-10-14-camera-backend-design.md`](docs/superpowers/specs/2026-10-14-camera-backend-design.md)
- **Thiết kế Mobile Flutter A1:** [`docs/superpowers/specs/2026-10-15-camera-mobile-a1-design.md`](docs/superpowers/specs/2026-10-15-camera-mobile-a1-design.md)
- **Báo cáo Nghiệm thu Mobile A1:** [`docs/ui/mobile-a1-verification.md`](docs/ui/mobile-a1-verification.md)
- **Design System & Mockups Stitch:** [`docs/ui/stitch/README.md`](docs/ui/stitch/README.md)
