# Camera — lượt xác minh runtime 3

Ngày 2026-10-14. Cùng bản runtime `com.fts.notis` 5.2.1/502001, `emulator-5554`, khác hash APK workspace như đã ghi. Phạm vi: khôi phục UI, Quan tâm, refresh, socket và một số nhánh lỗi/quyền.

## 1. Sửa nhận định về splash

**Quan sát runtime:** vuốt từ `(800,750)` lên `(800,250)` làm hiện menu chính; có thể mở Camera. Evidence REA `rea-pass3-scroll.json` và `ui-pass3-scroll.xml` trong `evidence/camera/`. Sau những lần restart tiếp theo, cũng vuốt lên và mở Camera được. **Rút lại nhận định app bị kẹt splash:** frame ở lượt 2 không đủ để kết luận lỗi khởi động. Không cần sửa cấu hình hay xóa data để tiếp tục.

Log kiểm tra thấy một cảnh báo App Check/Integrity và EGL; chưa có bằng chứng chúng gây ra frame lượt 2. Không coi cảnh báo là root cause. Thiết bị không có global HTTP proxy trong lần đọc (`null`).

## 2. Quan tâm phục hồi trên UI

**Quan sát runtime:**

1. Bắt đầu với key rỗng và UI rỗng (`storage-pass3-empty.json`, `rea-pass3-empty.json`).
2. Từ map chọn Khu vực → Nguyễn Huệ → marker Pasteur - Lê Thánh Tôn → tim. `storage-pass3-added-verified.json` có đúng camera `_id=5deb576d1dc17d7c5515ad13`.
3. Force-stop process PID 13129, launcher mở process mới PID 13560. Vuốt lên ở trang chính, vào Camera, chọn Quan tâm.
4. Camera có tên/thumbnail/tim đỏ xuất hiện trên UI mới: `rea-pass3-restored.json`, `ui-pass3-restored.xml`. Đây là thử nghiệm restore hoàn chỉnh, khác với file `rea-favorite-persisted.json` của lượt 2 vốn chỉ chụp banner.
5. Sau đo refresh, đóng preview và xóa bằng tim trên UI. `storage-pass3-cleaned.json` xác nhận `[]`; `rea-pass3-cleaned.json` ghi trạng thái UI. Không để lại favorite thử nghiệm.

**Giới hạn:** chưa xác minh đồng bộ tài khoản, offline restore, thứ tự hoặc giới hạn số camera. Lượt 2 đã sửa disk qua SharedPreferences API nhưng UI process còn giữ camera trong bộ nhớ; không dùng lần xuất hiện đó làm bằng chứng cho thử nghiệm restore mới. File `storage-pass3-added.json` là thao tác thử chưa thêm thành công (array rỗng); bằng chứng thêm hợp lệ là bản có hậu tố `-verified`.

## 3. Nhịp làm mới

**Quan sát runtime UI:** `scripts/sample-camera-counter.py` lấy 18 XML dump có cửa sổ thời gian start/end; file trong `evidence/camera/counter-pass3/`. Dãy counter: `10,8,6,3,1,9,8,5,4,0,10,7,5,3,1,9,5,4`. Ước lượng khoảng cách giữa các lần reset bằng midpoint cửa sổ: **12.045 và 12.045 giây**. Dump XML mất khoảng vài giây, không xem đây là đo timer chính xác tới millisecond.

Frame REA `rea-pass3-recovered.json` còn thấy số **11**; do đó nhận định ban đầu “counter luôn bắt đầu ở 10” chưa chính xác. Đặc tả nên ghi **nhịp khoảng 12 giây trong mẫu**, có đếm giảm/reset, thay vì hardcode 10 giây.

**Quan sát runtime socket:** `scripts/observe-camera-sockets.js` attach đúng PID 13560; chỉ ghi fd, peer, số bytes và thời gian, không đọc payload hoặc sửa TLS. `socket-refresh-pass3.jsonl` có ba write 159 bytes đến `109.237.69.7:443`, cách nhau **11.845 và 12.006 giây** khi mở camera. `api-dns-pass3.json` ghi DNS từ máy điều tra cho `api.notis.vn` trùng IP này.

**Suy luận:** các write lặp phù hợp nhịp tải camera khoảng 12 giây. Chưa giải mã HTTP, chưa chứng minh URL/path/method của từng write, không coi mỗi write là một HTTP request đã định danh. DNS app không được capture. Mẫu UI và mẫu socket thuộc hai cửa sổ đo khác nhau. `status.nextUpdate=12000` ở probe API phù hợp về số nhưng đơn vị và cách client sử dụng vẫn chưa được nối bằng code/hook.

Tổng hợp tính lại được: `scripts/summarize-camera-timing.py` → `timing-summary-pass3.json`. Probe symbols `native-symbols-pass3.txt` không thấy symbol SSL_read/SSL_write trong libflutter; không chứng minh không có TLS hoặc không thể hook.

## 4. Ngắt kết nối có giới hạn và hồi phục

**Quan sát runtime có can thiệp:** tạm REJECT TCP từ UID app `10063` tới `109.237.69.7:443` bằng một rule iptables OUTPUT; không tắt mạng toàn thiết bị. Thời điểm thêm/xóa rule trong `offline-start-pass3.txt`, `offline-restored-pass3.txt`. Chờ 18 giây rồi chụp frame/UI XML, sau đó xóa rule trong `finally`; kiểm tra rule đã vắng sau cleanup.

- `rea-pass3-offline.json`, `ui-pass3-offline.xml`: vẫn hiển thị ảnh và counter, không có nhãn lỗi/ảnh cũ rõ ràng trong frame này.
- `rea-pass3-recovered.json`, `ui-pass3-recovered.xml`: sau khôi phục kết nối, ảnh phương tiện khác xuất hiện, counter 11.

**Giới hạn:** không phải mất mạng toàn bộ; không chặn host khác/IPv6; không có HTTP error/status capture. Một frame không chứng minh app không bao giờ báo lỗi. Không kết luận cơ chế retry/cache chỉ từ việc giữ ảnh. Đây là cơ sở đề xuất hiển thị độ mới ảnh và trạng thái refresh lỗi cho app mới.

## 5. Tìm kiếm và quyền vị trí

**Quan sát runtime:** từ Xung quanh → Tìm vị trí → nhập `Go Dua` → bấm biểu tượng tìm kiếm. `rea-pass3-search-results.json`, `ui-pass3-search-results.xml`: có tiêu đề Kết quả tìm kiếm, không có dòng kết quả trong frame. Không biết nguyên nhân, không kết luận địa điểm không tồn tại hoặc API hỏng.

Xóa query → Chọn vị trí trên bản đồ: app mở hộp Yêu cầu cấp quyền vị trí (`rea-pass3-pick-location.json`). Bấm **Không**: vẫn vào bản đồ, bấm điểm hiển thị chấm tím (`rea-pass3-location-denied.json`). Nút Đồng ý ở đáy đang mờ; bấm chưa xác nhận được chọn vị trí/đổ danh sách camera (`rea-pass3-location-confirm.json`). Không đổi Android permission sang cho phép; không gán nguyên nhân disable nút là do quyền khi chưa có code/log xác nhận.

## 6. Spec sau lượt này và phần mở

Đã đóng: UI restore Quan tâm qua restart, nhịp refresh khoảng 12 giây trong mẫu, một nhánh ngắt host và hồi phục, một nhánh từ chối prompt vị trí. Đã sửa nhận định splash.

Còn mở: capture HTTP app để nối caller/method/path/headers/response; video/stream; refresh background; geocoding/chọn điểm thành công; quyền GPS cấp/thu hồi; auth, pagination và cache contract. Không đánh dấu spec backend đầy đủ. Phần snapshot/UI/Quan tâm có thể dùng làm yêu cầu tái dựng với dữ liệu/backend được cấp quyền.
