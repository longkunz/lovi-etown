# Reference người dùng — Camera v3

Ngày 2026-10-16. Đã mở xem cả ba ảnh local bằng view_image trước thiết kế. Bản copy giữ nguyên bytes; không chỉnh sửa ảnh.

| File | Ảnh nguồn | Nội dung quan sát |
|---|---|---|
| `grid-compact.jpg` | `8d6899421652960ccf43.jpg` | Grid gọn 3 cột, ảnh snapshot, favorite star, selector khu vực cạnh search |
| `location-dropdown.jpg` | `1b70775df84d7813215c.jpg` | Popover danh sách địa điểm dạng Liquid Glass trên nền ảnh camera, grid 2 cột |
| `grid-comfortable.jpg` | `82c3bbf134e1b4bfedf0.jpg` | Grid 2 cột có ảnh/tên/metadata, favorite overlay, glass dock |

Người dùng yêu cầu dùng các reference để sửa thiết kế: dropdown địa điểm, mode Card/Grid/List, ảnh trong list và infinite loading. References đã upload vào cùng project Stitch `15634181901662145156` bằng CLI; response JSON từng file lưu bên cạnh. CLI Windows in assertion lúc thoát process; cả ba response trả success/uploaded và screen IDs, cần dùng kết quả server để xác minh thay vì kết luận thất bại chỉ từ exit diagnostic.

Screen reference IDs: compact `3793399605126619314`, dropdown `6011334151206472736`, comfortable `13901783425361611016`. Các ảnh mô tả UI mẫu, không xác minh app nguồn, phiên bản, dữ liệu phường, số camera 718 hoặc trạng thái online. Không coi các tab thời tiết/account/map ở ảnh là yêu cầu mới ngoài A1.
