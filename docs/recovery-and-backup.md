# Quảng Trị, mất mạng và nguồn dự phòng

Đã thử trên AVD Android 13 `emulator-5580`, PID 3641, original APK và hook license entry đã cho phép. AVD mất kết nối trong bước chuẩn bị và được khởi động lại; sự cố AVD không dùng làm ca mất mạng của app.

## Quảng Trị

Catalog `/api/hls/quang-tri` trả HTTP 200. Mở hai nguồn `Ngập Lụt - Ba Lòng`, `Ngập Lụt - Ba Đồn`; đóng paywall/quảng cáo qua UI. Native log có WSS open và handshake_sent, nhưng không có frame decoder trong khoảng quan sát 10:56–10:59 của PID này. UI Ba Lòng vẫn spinner sau lần chờ, Ba Đồn chưa thấy hình.

Đây là xác nhận đường kết nối EVUP và một ca chưa phát thành công; chưa xác định nguyên nhân nguồn, protocol, quyền stream hoặc parser. Không kết luận toàn bộ camera Quảng Trị chết. [Summary](../evidence/runtime/recovery-summary.json), ảnh trong `qt-playing`, `qt-after-wait`, `qt-badon-detail`.

## Mất mạng và phục hồi

Nguồn Hà Nội An Dương Vương đang decode HEVC được dùng làm baseline. Chỉ thay cấu hình mạng của AVD nghiên cứu, không thay mạng Windows.

| Bước | Kết quả |
|---|---|
| Baseline | Frame HEVC được giải mã, bộ đếm tới ít nhất 540 trong log lưu trước ngắt mạng |
| Bật airplane mode, tắt Wi-Fi | Bảng route rỗng; UI đổi sang “Không tải được hình ảnh”, nút Báo lỗi/Thử lại |
| Tắt airplane mode, bật lại Wi-Fi | Đã khôi phục đúng trạng thái trước thử: disabled / wifi_on=1; có route eth0/wlan0 |
| Quan sát khoảng 29 giây sau khôi phục | UI vẫn màn lỗi, chưa thấy tự phát tiếp |
| Bấm Thử lại | Native session mở lại, có HEVC frame và UI trở về player |

Thời gian ghi nhận bằng đồng hồ thiết bị: offline 04:00:28 UTC, restore 04:00:44 UTC, vẫn lỗi 04:01:13 UTC ngày 2026-10-14. Chưa đo latency phục hồi chính xác; không suy ra mọi player đều có cùng hành vi. UI lỗi quy nguyên nhân có thể là hệ thống nguồn/thời tiết dù ca này do mất mạng thiết bị, là cơ hội cải thiện thông báo và auto-reconnect.

## Backup

DAE disassembly `TrafficCamera.fromJson` tại RVA `0x62cf1c` đọc `backupCamera`, parse đệ quy rồi gán object vào field tại tagged offset `0x47`. Nhánh nested dùng tham số để tránh parse backup tiếp. `HcmCameraCatalogRepository._cameraToJson` có nhánh ghi backup; `_overlayDistrictsFromAsset` giữ field này khi dựng object mới. Bằng chứng: `evidence/native/dae-traffic-camera.txt`, `dae-hcm-repository.txt`; đây là phân tích artifact, không phải source graph.

Trong mẫu API TP.HCM có 19 backup object; 12 primary ID trùng danh sách unavailable local, không backup ID nào trùng. Repository có `_filterUnavailable` gọi `GiaothongUnavailable.isUnavailableCamera`, nên số response API không đồng nghĩa số camera hiện trên UI. Chưa chứng minh mọi trường hợp khớp ID đều bị lọc ở runtime.

Đã mở qua tìm kiếm `Phan X` camera Phan Đăng Lưu – Phan Xích Long: nguồn chính GET Notis trả JPEG 200 lặp lại, UI có ảnh; backup descriptor dùng POST ở `camera.thongtingiaothong.vn`. `backup-detail-http.json` thu được request nguồn chính. Ca bổ sung sau đó gây lỗi DNS riêng Notis trong tiến trình: UI lỗi, chưa thấy DNS tới backup host trong 200 giây; xem [catalog-cache-favorites.md](catalog-cache-favorites.md). Không suy luận chức năng chuyển nguồn chỉ từ sự tồn tại descriptor hoặc suy rộng ca DNS thành mọi failure mode.

App Huế ở phiên trước còn có overlay “Đã tạm dừng để tiết kiệm dữ liệu / Nhấn để tiếp tục theo dõi”; ảnh/state `qt-resume` ghi nhận overlay. Đây là trạng thái pause riêng, chưa đo timeout.

Trong thao tác đóng quảng cáo, nút X và tim nằm gần cùng vùng màn hình; trạng thái chuyển bất đồng bộ khiến hai camera Hà Nội/Phan Đăng Lưu bị thêm favorite ngoài ý định. Đã bỏ lại hai favorite qua UI sau thử, giữ dữ liệu thử trước đó. Các state `backup-heart-restored`, `cleanup-hanoi-restored`, `cleanup-final-home` lưu kiểm chứng. Không clear data. Kiểm tra 75 HTTP record từ sáu capture đạt framing/status 200, token redaction và hash bốn APK gốc.
