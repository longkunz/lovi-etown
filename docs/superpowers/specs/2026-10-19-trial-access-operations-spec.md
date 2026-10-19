# Đặc tả T06 — Hợp đồng truy cập và vận hành bản dùng thử A1

Ngày chốt: 2026-10-19. Chủ repo đã duyệt từng quyết định qua hỏi–đáp (8 câu) trong phiên làm việc của ticket #6. Spec này là căn cứ để rà soát và triển khai T07 (truy cập theo hợp đồng mới) và T08 (môi trường HTTPS + sao lưu/khôi phục). **Spec không tự cho phép mua dịch vụ hay triển khai trả phí** — việc thuê VPS/domain thuộc T08 và cần duyệt riêng tại thời điểm đó.

## Bối cảnh và nguyên tắc

- Bản dùng thử phục vụ một nhóm kín; app đọc camera công khai qua backend proxy, **không thêm yêu cầu đăng nhập** ở bất kỳ tầng nào.
- Reader key nhúng trong app **không được coi là bí mật**: bất kỳ ai có bản cài đều trích xuất được key. An toàn của hệ thống dựa vào (a) key chỉ có quyền đọc, (b) rate limit, (c) cache snapshot/ETag giảm tải upstream, (d) khả năng xoay key có cửa sổ chồng lấp, và (e) upstream credential không bao giờ rời backend (đã là hành vi hiện tại: proxy che giấu token/IP nguồn, chống rò rỉ qua redirect/descriptor).
- Backend hiện tại đã có sẵn phần lớn nền tảng: `ApiKeyGuard` với hai key tách biệt (`BACKEND_API_KEY` cho đọc, `ADMIN_API_KEY` cho route `@AdminOnly`, cấu hình bắt buộc hai key khác nhau) và `RateLimitInterceptor` đếm theo cặp (key + IP) với mã lỗi `RATE_LIMIT_EXCEEDED` (429, retryable). Các quyết định dưới đây chốt cấu hình và phần còn thiếu, không thiết kế lại.

## Các quyết định

### D1 — Mô hình truy cập: giữ mô hình hiện tại

App mang một reader key chung (định danh client, không phải bí mật) trong header `x-api-key` cho mọi route đọc; route quản trị (đồng bộ/import catalog) yêu cầu `ADMIN_API_KEY` riêng và key quản trị **không bao giờ** đi vào app hay bản build. Thiếu/sai key → `401 UNAUTHORIZED` (mã lỗi có cấu trúc như hiện tại).

*Đánh đổi:* key bị chia sẻ ngoài nhóm là không tránh khỏi về mặt kỹ thuật; chấp nhận vì dữ liệu camera là công khai và các lớp D2/D3/D5 giới hạn thiệt hại. Phương án key theo từng bản cài bị loại vì vẫn không tạo được bí mật thật mà tăng độ phức tạp vận hành.

### D2 — Rate limit: 120 request/phút mỗi (key + IP)

Giữ nguyên mặc định hiện tại `RATE_LIMIT_MAX_PER_MINUTE=120`, cửa sổ 60 giây, vượt giới hạn trả `429 RATE_LIMIT_EXCEEDED`. Con số này là cấu hình môi trường, đổi được không cần sửa code.

*Đánh đổi:* nhiều người dùng thử chung một IP công cộng (NAT) có thể chạm trần oan; app đã có hành vi backoff tôn trọng 429 (T02) nên hệ quả là tạm chậm chứ không sập. T08 đo tần suất 429 oan trong giai đoạn dùng thử; nếu có bằng chứng chạm trần thường xuyên, nâng giới hạn bằng biến môi trường và ghi lại quyết định.

### D3 — Xoay key: cửa sổ chồng lấp 7 ngày

Backend chấp nhận đồng thời reader key hiện tại và **một reader key trước đó** (cấu hình tùy chọn, ví dụ `BACKEND_API_KEY_PREVIOUS`) trong 7 ngày kể từ khi xoay. Sau cửa sổ, chỉ key hiện tại hợp lệ. Quy trình xoay: sinh key mới → bật key mới + key cũ ở backend → phát hành bản app dùng key mới → sau 7 ngày gỡ key cũ khỏi cấu hình.

*Việc T07 phải làm:* hỗ trợ key trước đó trong guard + test cho cả hai key trong cửa sổ và hành vi hết cửa sổ. Admin key không có cửa sổ chồng lấp (chỉ dùng bởi vận hành, xoay cứng được).

### D4 — Hợp đồng lỗi phía client

- `401/403` (key bị thu hồi hoặc hết cửa sổ chồng lấp): app hiển thị **màn hình riêng "cần cập nhật app"**, không nút thử lại, không polling tiếp; dữ liệu Quan tâm của người dùng được giữ nguyên.
- `429`: app tự backoff theo `Retry-After`/backoff lũy thừa, giữ khung hình cuối và đánh dấu cũ (hành vi đã có từ T02 — spec này phê chuẩn và T07 bổ sung regression test ở tầng API + UI).
- Lỗi nguồn (upstream camera mất tín hiệu, backend trả lỗi nguồn/5xx): phân biệt với lỗi cấu hình/mạng trong thông điệp hiển thị — người dùng phải phân biệt được "camera đang mất tín hiệu" với "app/hệ thống lỗi".

### D5 — Môi trường đích: một VPS nhỏ + Docker Compose + Caddy

Một VPS duy nhất chạy toàn bộ bằng Docker Compose: backend, PostgreSQL/PostGIS, và Caddy làm reverse proxy với TLS Let's Encrypt tự động. Domain riêng trỏ về VPS; app chỉ nói chuyện qua HTTPS. Cấu hình triển khai dùng giá trị bí mật riêng của môi trường, không dùng giá trị mẫu trong repo.

*Ngân sách:* tổng chi phí vận hành mục tiêu **dưới 1.000.000 đồng/tháng** (VPS + domain quy đổi theo tháng). Đây là mục tiêu cần **kiểm chứng ở T08** bằng hóa đơn/cấu hình thực tế, không coi là đã đạt khi chưa triển khai.

*Đánh đổi:* một điểm chết duy nhất — VPS hỏng thì dịch vụ ngừng; chấp nhận ở giai đoạn dùng thử kín vì chi phí và độ đơn giản, và vì dữ liệu có thể dựng lại (xem D7).

### D6 — Phạm vi phát hành thử: nhóm kín tối đa ~20 người

Chủ repo + tối đa khoảng 20 người được mời; phân phối bằng file APK/link riêng, **không** qua store, không công khai link. Mở rộng phạm vi là quyết định riêng sau khi có số liệu tải/chi phí từ T08.

### D7 — Tải mục tiêu: 20 người xem đồng thời, p95 snapshot < 500 ms

Thiết kế và kiểm chứng ở mức **20 người xem đồng thời** (mỗi người polling một camera theo chu kỳ 12 giây cộng burst cuộn danh sách). Tiêu chí đo: tại mức tải đó, **p95 độ trễ snapshot trúng cache < 500 ms**, không phát sinh 5xx. T08 chạy bài kiểm tải nhỏ đúng các con số này và ghi kết quả; vượt tiêu chí là căn cứ nâng cấp VPS hoặc điều chỉnh cache trước khi mở rộng phạm vi (D6).

### D8 — Log và sao lưu: mức tối thiểu

- Log ứng dụng giữ **7 ngày** trên VPS (xoay vòng).
- Backup cơ sở dữ liệu **hằng ngày, giữ 3 bản gần nhất, lưu trên cùng VPS**.

*Rủi ro đã chấp nhận:* VPS mất hoàn toàn thì mất cả backup. Chấp nhận được vì catalog dựng lại được từ nguồn/import (T08 kiểm chứng đường import giới hạn), Quan tâm nằm trên thiết bị người dùng, và giai đoạn này là dùng thử kín. Nếu sau này dữ liệu vận hành trở nên không thể dựng lại, quyết định này phải được xem xét lại trước khi mở rộng phạm vi.

## Tiêu chí vận hành (đo ở T08)

1. Luồng app qua HTTPS chạy đủ: migration → import giới hạn → list/detail/snapshot/304 (đúng AC của T08).
2. Kiểm tải nhỏ ở mức D7 đạt tiêu chí p95 và không 5xx.
3. Khôi phục một bản backup vào DB tách biệt, đối chiếu catalog/ID khớp.
4. Restart/rollback dịch vụ theo runbook không mất dữ liệu ngoài cửa sổ backup.
5. Chi phí tháng thực tế đối chiếu trần D5.

## Các seam kiểm thử cho T07/T08

- **API:** key hợp lệ/không hợp lệ/key cũ trong và ngoài cửa sổ chồng lấp; admin key không đọc nhầm quyền và reader key không gọi được route quản trị; 429 sau đúng ngưỡng cấu hình; descriptor/redirect/log không chứa upstream secret (regression theo A1).
- **UI:** màn hình "cần cập nhật app" khi 401/403; trạng thái 429 (backoff + frame cũ được đánh dấu); thông điệp lỗi nguồn khác lỗi cấu hình.
- **Vận hành (T08):** khôi phục backup + đối chiếu; đo tải theo D7; đối chiếu chi phí theo D5.

## Ngoài phạm vi

- Đăng nhập/tài khoản người dùng (chủ repo đã loại từ đầu).
- Phát hành App Store/Google Play.
- Tự động mua/thuê hạ tầng — T08 thực hiện sau duyệt riêng.
