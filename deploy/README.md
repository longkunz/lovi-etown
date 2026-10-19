# Runbook triển khai bản dùng thử (T08)

Bộ này hiện thực đặc tả T06 (D5–D8) cho môi trường dùng thử: **một VPS nhỏ** chạy Docker Compose (backend + PostgreSQL/PostGIS + Caddy HTTPS), phục vụ **nhóm kín tối đa ~20 người**, ngân sách mục tiêu **dưới 1.000.000 đồng/tháng**.

Trạng thái: bộ triển khai đã sẵn sàng và đã kiểm tra cú pháp, **chưa triển khai thật**. Việc thuê VPS, mua domain và đưa secret thật vào thuộc bước triển khai T08 và cần chủ repo duyệt riêng — không tự động thực hiện.

## Thành phần

| File | Vai trò |
| --- | --- |
| `compose.prod.yml` | Stack production: `db` (PostGIS 17-3.5, chỉ nội bộ), `backend` (build từ `backend/Dockerfile`), `caddy` (cổng 80/443, TLS tự động) |
| `Caddyfile` | Reverse proxy `{$DOMAIN}` → `backend:3000`, gzip, ẩn header server |
| `.env.prod.example` | Mẫu biến môi trường; bản thật `.env.prod` chỉ nằm trên VPS, không commit |
| `backup.sh` | Backup DB hằng ngày, giữ 3 bản mới nhất (D8) |
| `restore.sh` | Khôi phục backup vào DB tách biệt để đối chiếu (từ chối ghi vào DB production) |
| `load-test.mjs` | Kiểm tải nhỏ theo D7: 20 người xem đồng thời, tiêu chí p95 snapshot < 500 ms và không 5xx |

## Chuẩn bị (làm một lần, cần chủ repo duyệt chi phí)

1. Thuê 1 VPS (gợi ý tối thiểu 2 vCPU / 2 GB RAM / 40 GB SSD) và một domain (hoặc subdomain) trỏ bản ghi A về IP của VPS. Ghi lại chi phí tháng thực tế để đối chiếu trần D5.
2. Trên VPS: cài Docker + Docker Compose plugin, tạo thư mục `/opt/lovi-etown`, clone repo, mở cổng 80/443 (và 22 cho SSH, nên giới hạn theo IP).
3. Tạo khóa thật (mỗi khóa ≥ 32 ký tự ngẫu nhiên, tất cả khác nhau):
   - `openssl rand -hex 32` cho `BACKEND_API_KEY`, `ADMIN_API_KEY` và `POSTGRES_PASSWORD`.
   - Reader key này sẽ nhúng vào bản build app của nhóm dùng thử — coi như định danh client, không phải bí mật (D1).

## Triển khai lần đầu

```bash
cd /opt/lovi-etown/deploy
cp .env.prod.example .env.prod   # điền giá trị thật, gồm DOMAIN
docker compose -f compose.prod.yml --env-file .env.prod up -d --build
docker compose -f compose.prod.yml --env-file .env.prod exec backend npm run db:migrate
# Nạp catalog: đồng bộ từ nguồn (giới hạn theo cấu hình) bằng key quản trị
docker compose -f compose.prod.yml --env-file .env.prod exec backend npm run camera:sync
curl https://<DOMAIN>/health/live
```

Sau đó build app với `BACKEND_URL=https://<DOMAIN>` và reader key tương ứng, phát cho nhóm kín (D6).

## Kiểm chứng nghiệm thu T08

1. **Luồng qua HTTPS từ app:** list → detail → snapshot → 304 (dùng app thật hoặc test smoke AC3 trỏ `T03_BACKEND_URL` vào domain).
2. **Kiểm tải:** `BACKEND_URL=https://<DOMAIN> READER_KEY=<reader-key> node load-test.mjs` — đạt khi p95 < 500 ms, không 5xx (lưu ý: script dùng một IP nên có thể gặp 429 nếu nhiều viewer dùng chung key+IP; ghi lại nếu xảy ra để đối chiếu D2).
3. **Sao lưu/khôi phục:** chạy `./backup.sh`, rồi `./restore.sh backups/<file> catalog_verify`, so sánh số dòng bảng `cameras` giữa hai DB, xong xóa DB verify.
4. **Restart/rollback:** `docker compose ... restart backend` phải không mất dữ liệu; rollback = checkout commit trước + `up -d --build`.

## Vận hành thường lệ

- **Xem log** (giữ 7 ngày theo D8 — cấu hình xoay vòng log của Docker trên VPS: `max-size=10m, max-file=7` cho mỗi container hoặc journald tương đương):
  `docker compose -f compose.prod.yml --env-file .env.prod logs -f backend`
- **Backup tự động:** thêm cron chạy `backup.sh` mỗi ngày (ví dụ trong đầu file `backup.sh`).
- **Xoay reader key (D3):** sinh key mới → đặt `BACKEND_API_KEY=<mới>` và `BACKEND_API_KEY_PREVIOUS=<cũ>` trong `.env.prod` → `up -d` → phát hành bản app dùng key mới → sau 7 ngày gỡ dòng `BACKEND_API_KEY_PREVIOUS` và `up -d` lần nữa.
- **Cập nhật bản mới:** pull commit mới → `up -d --build` → chạy migration nếu có.

## Giới hạn đã biết (theo spec T06)

- Một điểm chết duy nhất: VPS hỏng là dịch vụ ngừng và **mất cả backup** (D8 — rủi ro đã chấp nhận; catalog dựng lại được bằng `camera:sync`, Quan tâm nằm trên thiết bị).
- Chứng thư TLS phụ thuộc Let's Encrypt qua Caddy; domain phải trỏ đúng IP trước lần chạy đầu.
- Chưa gồm phát hành App Store/Google Play (ngoài phạm vi T08).
