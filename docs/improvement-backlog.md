# Cải tiến đề xuất

Đây là backlog để review, chưa phải yêu cầu sản phẩm đã chốt. Giả định: phục vụ người dùng kiểm tra tình hình đường trước chuyến đi. Cần xác nhận giả định này trước khi chọn các tính năng chuyên sâu.

| ID / ưu tiên | Cơ sở và thay đổi đề xuất | Tiêu chí nghiệm thu dự kiến | Chi phí / phụ thuộc |
|---|---|---|---|
| IMP-01 / P0 | R-009/R-019/R-020: Quảng Trị handshake chưa có frame; mất mạng Hà Nội hiện lỗi nguồn/thời tiết, có mạng lại ~29 giây vẫn cần Retry. Phân biệt mạng/TLS/nguồn, auto-reconnect có backoff và fallback khi nguồn cho phép | Không loading vô hạn; dừng retry khi rời màn; thử nối lại khi mạng phục hồi; hiển thị nguyên nhân và thời điểm kiểm tra | Cao; cần nguồn hợp lệ, contract lỗi và Android matrix |
| IMP-02 / P0 | Quảng cáo/paywall chen flow: cho người dùng hoàn tất lượt xem đầu trước quảng bá, cung cấp đường quay lại rõ | Ca mở camera lần đầu tới nội dung hoặc lỗi nguồn mà không bị toàn màn quảng bá chặn | Trung bình; cần chốt mô hình doanh thu |
| IMP-03 / P0 | Nguồn snapshot có thể cũ: tách thời điểm ảnh với thời điểm tải, báo stale/unknown, hiển thị sức khỏe nguồn | Ảnh fixture cũ/thiếu timestamp được đánh dấu đúng; không gọi thời điểm tải là thời điểm chụp | Trung bình; phụ thuộc metadata nguồn |
| IMP-04 / P0 | Nới TLS trong native code: dùng TLS chuẩn và quản lý compatibility theo nguồn | Test cert không hợp lệ bị từ chối; nguồn hợp lệ hoạt động trên Android mục tiêu; log che URL/token | Trung bình/cao; có thể cần nguồn thay thế |
| IMP-05 / P1 | Favorites có sẵn: thêm nhóm theo tuyến/chuyến đi, truy cập nhanh và label riêng | Chọn nhóm mở đúng camera; favorites còn sau restart; camera bị gỡ có trạng thái rõ | Trung bình; giá trị cần xác nhận với người dùng |
| IMP-06 / P1 | Danh sách nhiều tỉnh: tìm không dấu, alias địa danh, bộ lọc nhất quán | Query có/không dấu trả cùng tập fixture; query rỗng/no match có state rõ; không tự gộp camera chỉ vì tên giống | Trung bình; cần catalog chuẩn hóa |
| IMP-07 / P1 | Catalog/cache local: vẫn xem được metadata/favorites offline với nhãn dữ liệu cũ | Mất mạng vẫn duyệt cache; không giả lập video live; phục hồi mạng refresh có giới hạn | Trung bình; cần TTL/version catalog |
| IMP-08 / P2 | Camera Quảng Trị có tên Ngập Lụt: chế độ theo dõi mưa/ngập theo khu vực là giả thuyết mở rộng | Chỉ công bố cảnh báo khi có nguồn xác thực và thời điểm; không suy ra ngập từ tên camera | Cao; nguồn dữ liệu bổ sung, kiểm chứng giá trị |

MVP đề xuất tập trung IMP-01–04 và các tính năng cơ bản đã quan sát. IMP-05–08 cần chọn theo nhu cầu thực tế, không mặc định phải có để khác biệt.
