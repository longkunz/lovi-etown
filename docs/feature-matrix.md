# Tính năng và phạm vi kiểm chứng

Tất cả quan sát UI dưới đây dùng phiên có Frida bỏ kiểm tra license local, bản 2.0.0 trên emulator-5554. XML và screenshot có thể lệch thời điểm do animation/semantics cập nhật trễ; ưu tiên ảnh khi hai nguồn không khớp. Trace Dart chỉ là ứng viên theo tên trong E-05.

| ID | Tính năng | Đã quan sát | Bằng chứng / còn thiếu |
|---|---|---|---|
| F-001 | Chọn/đổi tỉnh | Đã mở danh sách riêng của cả năm tỉnh TP.HCM, Hà Nội, Đà Nẵng, Huế, Quảng Trị | hooked-launch-window.xml, province-picker và các state *-home; chưa xác minh toàn bộ catalog |
| F-002 | Onboarding vị trí | Giải thích mục đích, Tiếp tục / Để sau; chọn Để sau vẫn vào danh sách | location-disclosure; lời hứa privacy là copy UI, chưa kiểm toán data flow vị trí |
| F-003 | Danh sách camera | TP.HCM có thumbnail và quận, Hà Nội có tên và địa chỉ | hcm-home, hanoi-home; chưa xác minh số lượng toàn bộ |
| F-004 | Tìm kiếm | Có ô tìm theo tên/địa chỉ; query không khớp tại Quảng Trị hiện thông báo không tìm thấy | search-empty; chưa kiểm chứng không dấu/alias hoặc relevance |
| F-005 | Lọc | TP.HCM có danh sách quận/khu vực; Mặc định / Gần tôi / Yêu thích | hcm-districts, hcm-filters; chưa thử xếp hạng khoảng cách |
| F-006 | Chi tiết camera | TP.HCM có snapshot JPEG thật từ Notis hiện trên chi tiết, fullscreen, bản đồ, nút tim và danh sách liên quan | dart-hcm-snapshot-visible và dart-capture/pass2-http.json; chưa đo refresh chính xác |
| F-007 | Yêu thích | Thêm 11B rồi xuất hiện ở tab Yêu thích và còn sau spawn lại app | favorites, dart-hcm-list; chưa phục hồi storage implementation/key |
| F-008 | Bản đồ | Màn bản đồ riêng, danh sách, xem camera gần nhất, traffic, 2D, zoom, vị trí | map; chưa kiểm chứng marker/traffic live và kết quả khi cấp quyền |
| F-009 | VIP/paywall | Có màn Nâng cấp VIP, gói trọn đời, mua/khôi phục/chính sách/điều khoản | hanoi-detail-confirmed/screen.png là paywall dù XML còn home; giá hiển thị '- đ', không xác nhận giá thực |
| F-010 | Cài đặt | Góp ý, đánh giá, chính sách, version, đề xuất app khác | settings; chưa mở external app/email |
| F-011 | Quảng cáo | UI banner / đề xuất app; log load OPEN AD, INTER AD, RewardedAd | hcm screenshot, favorites/settings, hooked-logcat-local.txt; chưa chốt điều kiện mọi placement |
| F-012 | Playback đa nguồn | Mã có snapshot/HLS/EVUP; runtime Hà Nội gọi EVUP WSS và lỗi TLS protocol version | E-05, p161w1, playback-redacted.txt, after-ad-back; chưa quan sát đủ phiên video phát thành công |

Điểm khác nhau đã thấy: TP.HCM có lọc khu vực riêng; Hà Nội hiển thị địa chỉ dài và không có dropdown khu vực trong state đã chụp. Không suy rộng sang các tỉnh chưa kiểm tra.
