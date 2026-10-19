# Player Đà Nẵng và Huế — Android 13

Đã mở camera tự nhiên qua UI trên `emulator-5580`, original APK, không sửa source URL hoặc entitlement. Paywall đóng bằng nút X; quảng cáo đóng bằng Back. Không thao tác mua hoặc mở link quảng cáo.

| Mẫu đã thử | Metadata API | Runtime |
|---|---|---|
| Bệnh viện Đà Nẵng | `(isHls,hlsType)=(1,5)`, source identifier | UI có YouTube Video Player, tiêu đề video, nút Pause và nhãn Live; ảnh hiển thị bệnh viện/đường phố |
| Cầu Lòn Bùi Thị Xuân1, Huế | `(1,2)`, URL HTTP `.m3u8` | Hiển thị camera đường phố, phương tiện thay đổi giữa hai ảnh; log cùng PID/thời điểm có `media_kit_video.VideoOutputManager.create` và kích thước 640×360 |

Response catalog Đà Nẵng và Huế trong `dart-capture/players33b-http.json` đều HTTP 200, framing đầy đủ. [Summary](../evidence/runtime/players33-summary.json) đối chiếu đúng tên/ID/flags, giữ hash source thay cho URL thô và hash screenshot. [Đà Nẵng](../evidence/runtime/players33-danang-detail/screen.png), [Huế lần 1](../evidence/runtime/players33-hue-detail/screen.png), [Huế lần 2](../evidence/runtime/players33-hue-playing2/screen.png).

Kết luận: type5 đã xác nhận renderer YouTube với một camera; type2 đã xác nhận playback nhìn thấy được và khởi tạo media_kit. Chưa thu HTTP playlist/segments vì observer hiện chỉ đọc TLS trong Flutter, còn URL Huế là HTTP plain. Không gán log VP9 từ Chromium cho Huế: WebView quảng cáo và YouTube cũng phát video trong cùng process.

Danh sách API chỉ cung cấp descriptor. App có nhiều đường xử lý: snapshot TP.HCM → ảnh HTTP, type4 Hà Nội → native EVUP/HEVC, type5 Đà Nẵng → YouTube embed, type2 Huế → media_kit. Chưa kiểm tra hết camera, Quảng Trị playback, fallback/backup, reconnect hoặc background.

Collector attach ban đầu tìm process theo package name không thấy dù app đang chạy (tên process Frida không khớp package). Đã sửa để chọn running application theo identifier và lấy PID; phiên `players33b` attach đúng PID 8605. Phiên lỗi `players33` không được dùng làm capture thành công.
