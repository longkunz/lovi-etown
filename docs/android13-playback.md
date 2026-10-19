# Hà Nội: EVUP phát thành công trên Android 13

AVD nghiên cứu riêng `Camera_Research_API33`, serial `emulator-5580`, Android 13/API 33 x86_64, chạy original split APK. Hook license entry đã được người dùng cho phép; không sửa APK, VIP hoặc TLS verification. AVD và dữ liệu chạy nằm trong `analysis/emulator/`, được git-ignore.

Mở danh sách Hà Nội, chọn `An Dương Vương – Đường Dẫn Cầu Nhật Tân – C149.08-PTZ`. Log native có 2 `wss_open`, 2 `handshake_sent`, decoder `c2.goldfish.hevc.decoder`; bộ đếm frame cao nhất ghi nhận 3390. [Ảnh màn hình](../evidence/runtime/api33-hanoi-playing/screen.png) thể hiện đường và phương tiện trong vùng video. [Summary](../evidence/runtime/api33-playback-summary.json) giữ build fingerprint, decoder, counters và hash log gốc; không chứa URL có credential.

Luồng đã xác nhận: POST catalog Hà Nội → descriptor WSS → native EVUP WebSocket → handshake → HEVC decode → video trên UI. Capture `api33pass1-http.json` có hai response catalog HTTP 200, không có framing limitation.

Android 9 trước đó lỗi `TLSV1_ALERT_PROTOCOL_VERSION`; Android 13 lần này phát được. Các phiên khác OS, emulator, thời điểm và có thể điều kiện mạng, nên chưa kết luận OS là nguyên nhân duy nhất. Kết quả áp dụng một nguồn Hà Nội đã thử; chưa chứng minh toàn bộ WSS, Quảng Trị, HLS Huế hoặc reconnect/background. Counter decoder không phải phép đo FPS hay benchmark hiệu năng.
