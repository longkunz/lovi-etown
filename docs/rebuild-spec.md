# Đặc tả tái dựng chức năng theo dõi camera

Phiên bản dự thảo 1 — 2026-10-14. Phạm vi: camera giao thông, từ chọn camera đến xem ảnh và lưu Quan tâm. Không phải camera chụp ảnh của điện thoại. Tài liệu này đủ để phát triển UI và tích hợp backend giả lập; tích hợp nguồn thật còn phụ thuộc hợp đồng và quyền nguồn dữ liệu.

**Cập nhật bằng chứng lượt 7:** đã capture method/path/header names/status HTTP app cho list/snapshot/search và bootstrap; body tenants xác nhận nguồn cấu hình. Xem [debug API](camera-api-debug-pass7.md). Các đoạn bên dưới ghi chưa capture snapshot là trạng thái khi soạn dự thảo: nay còn thiếu Dart handler và contract cache/auth bắt buộc/pagination đầy đủ, không còn thiếu method/path app trong mẫu đã thu. Quyền sử dụng provider và đề xuất thiết kế vẫn cần chốt độc lập.

## 1. Cơ sở và mức độ xác minh

**Quan sát runtime:** Camera có ba tab Quan tâm/Bản đồ/Xung quanh; chọn marker hoặc thẻ mở preview; thêm/xóa Quan tâm và phục hồi sau restart; chọn khu vực đổi tâm bản đồ; chọn điểm thủ công trên Android 13 khi GPS denied vẫn trả danh sách và mở ảnh. Bằng chứng: [camera-spec.md](camera-spec.md), REA `ev_a1679de9f50a8cbf7c332c02c59b8c69a6f422a383a61c2d252cb9545bbb1c0b`, `ev_bb423f8e0d8fabaa2e2315ca37e327c056858f878764702d0e489661c1da79fc`, `ev_db651d49917052345ed699b07d1482ee889996036e26a72ee6a72f10b5b6c4ae`.

**Quan sát runtime có giới hạn:** snapshot đổi ảnh với nhịp khoảng 12 giây trong mẫu; background 30 giây không thấy write host ảnh qua hooks, resume gửi lại. LIVE đã mở nhưng không phát thành công, Android chặn cleartext. Xem [lượt 3](camera-runtime-pass3.md), [lượt 4](camera-runtime-pass4.md).

**Quan sát tĩnh:** APK dùng Flutter/Dart AOT; chưa phục hồi handler camera Dart. Workspace APK và runtime APK khác hash dù cùng `com.fts.notis` 5.2.1 (502001); bảng danh tính nằm trong camera-spec. Không khẳng định runtime đã mô tả chính xác mọi hành vi của APK workspace.

**Probe độc lập:** endpoint trả camera/snapshot, nhưng nearby chưa chứng minh đủ mọi camera trong bán kính. 90 không phải số kết quả cố định. Xem [API catalog](api-catalog.md), [lượt 6](camera-contract-pass6.md). Method/header snapshot app và phân trang vẫn chưa xác minh.

Mọi yêu cầu từ mục 2 trở đi là **thiết kế đề xuất cho app mới**, không phải khẳng định nội bộ app gốc hoặc cải tiến đã được chọn triển khai.

## 2. Phạm vi chức năng

| ID | Yêu cầu | Nghiệm thu |
|---|---|---|
| R-01 | Entry Camera và ba tab | Mở được từ trang chính; đổi tab giữ danh sách Quan tâm và vị trí đã chọn trong phiên |
| R-02 | Bản đồ camera | Marker đặt đúng tọa độ; chọn A luôn mở tên/ảnh A; pan/zoom tải dữ liệu cho viewport mới; response cũ không ghi đè viewport mới |
| R-03 | Preview snapshot | Có tên, ảnh đúng tỷ lệ, tim, đóng và trạng thái tải; mở B khi A đang tải không hiển thị nhầm ảnh A |
| R-04 | Làm mới | Interval cấu hình, mặc định đề xuất 12 giây; mỗi camera đang xem tối đa một request đang chạy; đóng preview/background dừng polling; resume làm mới, không tạo timer trùng |
| R-05 | Quan tâm | Thêm từ thẻ/preview không trùng; tim nhất quán giữa các tab; lưu bền local; restart vẫn còn; xóa cập nhật ngay; rỗng có hướng dẫn |
| R-06 | Khu vực | Danh sách lấy từ cấu hình nguồn; chọn cập nhật nhãn/tâm bản đồ; không hardcode 16 khu vực nếu nguồn thay đổi |
| R-07 | Xung quanh | Chọn điểm → xác nhận → tải camera trong radius mặc định 5000 m; hiện tên/thumbnail/khoảng cách km; sắp tăng khoảng cách theo contract; bấm thẻ mở đúng preview |
| R-08 | Vị trí thủ công | GPS denied vẫn chọn/xác nhận tọa độ; nếu không lấy được địa chỉ, cho dùng tọa độ với nhãn rõ thay vì chặn toàn bộ flow |
| R-09 | Tìm địa điểm | Nhập query, tải kết quả từ provider được phép dùng; chọn kết quả cập nhật điểm; phân biệt không có kết quả và provider lỗi; bỏ response của query cũ |
| R-10 | Vị trí hiện tại | Chỉ xin quyền khi người dùng chọn thao tác; denied hoặc dịch vụ vị trí tắt có hướng dẫn và lối chọn thủ công; đây là yêu cầu mới chưa tái hiện flow GPS thành công ở app gốc |
| R-11 | LIVE có điều kiện | Chỉ bật khi có nguồn stream được cấp quyền và player hỗ trợ; loading có timeout/lỗi/thử lại/quay về snapshot; nghiệm thu nguồn mẫu HTTPS phát được; không coi đuôi m3u8 là đủ chứng minh phát được |

Đồng bộ tài khoản, thông báo giao thông, xem lịch sử video, PTZ, download/chia sẻ ảnh và camera theo tuyến chưa thuộc phạm vi dự thảo. Field `ptz` trong response không phải bằng chứng app gốc có điều khiển PTZ.

## 3. Mô hình dữ liệu độc lập

| Entity | Trường tối thiểu | Quy tắc |
|---|---|---|
| Camera | `sourceId`, `tenantId`, `displayCode?`, `name`, `latitude`, `longitude`, `snapshotRef`, `streamRef?`, `availability?` | Khóa nguồn khác mã hiển thị; kiểm tra tọa độ; không đưa IP camera nội bộ vào UI |
| Snapshot | `cameraId`, `imageRef`, `receivedAt`, `capturedAt?`, `refreshAfterMs?` | Không suy giờ chụp từ giờ nhận; timestamp nguồn chưa rõ nghĩa phải để unknown |
| Favorite | `tenantId`, `cameraId`, `addedAt`, `cachedName?` | Unique theo tenant/camera; lưu ID và metadata tối thiểu; camera bị xóa vẫn có trạng thái không khả dụng và cho bỏ Quan tâm |
| Area | `id`, `name`, `center`, `bounds?` | Lấy theo tenant/provider |
| SelectedLocation | `latitude`, `longitude`, `label?`, `selectionSource` | Phân biệt điểm thủ công/kết quả tìm/GPS; địa chỉ không bắt buộc để xem camera |
| CameraPage | `items`, `nextCursor?`, `total?`, `complete`, `effectiveRadiusM?` | Không tự suy `total` bằng số record đã tải; thiếu metadata thì đánh dấu tính đầy đủ chưa biết |

Adapter chuyển `[lng,lat]` của nguồn sang lat/lng của domain; chuyển đơn vị khoảng cách theo hợp đồng backend. Không giả định `status.imageTs` là giờ chụp hoặc `nextUpdate` là milliseconds trước khi provider xác nhận.

## 4. Hợp đồng backend cần có

Tên thao tác bên dưới là interface đề xuất, chưa phải endpoint của app gốc:

| Interface | Input | Output / điều kiện |
|---|---|---|
| `listCamerasInBounds` | tenant, bounds, cursor? | CameraPage; quy tắc bounds và trang rõ ràng |
| `listNearbyCameras` | tenant, lat, lng, radiusM, cursor? | CameraPage; thứ tự tăng khoảng cách, radius thực tế, cách lấy hết trang |
| `getSnapshot` | tenant, cameraId, validator? | Ảnh/ref + metadata freshness; hỗ trợ 304 nếu contract có; quy định timeout/cache/error |
| `listAreas` | tenant | Area[] và phiên bản cấu hình nếu có |
| `searchPlaces` / `reverseGeocode` | query hoặc tọa độ | Danh sách địa điểm hoặc địa chỉ; lỗi/rate limit rõ; fallback tọa độ |
| `getStreamAccess` | tenant, cameraId | Nguồn HTTPS tương thích player, hạn dùng nếu có; không log credential/query bí mật |

**Phương án dữ liệu đề xuất:** phát triển bằng fixture/backend giả lập độc lập trước; sản phẩm thật dùng provider đã cho phép hoặc backend của chủ sản phẩm. Adapter nguồn gốc chỉ được tích hợp khi quyền dùng, auth, quota, cache, radius/pagination và media contract được xác nhận. Endpoint phát hiện trong APK không tự xác nhận khả năng tái sử dụng.

Fixture phải có: danh sách rỗng; nhiều trang; camera cùng tên khác ID; thiếu ảnh/stream; camera ngừng hoạt động; response chậm; 404/429/5xx; geocoder lỗi; snapshot không đổi; snapshot mới đến sau khi chuyển camera. Dùng ảnh mẫu do dự án có quyền sử dụng.

## 5. State và nhánh lỗi

Danh sách: `idle → loading → ready | empty | error`; khi đang có dữ liệu, refresh lỗi giữ dữ liệu cũ kèm thông báo. Không hiển thị màn trắng như trạng thái mặc định.

Preview: `closed → loading → showing | error`; refresh giữ ảnh cuối và trạng thái làm mới; lỗi không reset tuổi ảnh. Close/background hủy timer, bỏ kết quả request đã hết hiệu lực. Resume tải lại khi preview còn mở.

Không có total/complete đáng tin: hiện “Đã tải N camera”; không nói “Tất cả camera trong 5 km”. Hết trang theo contract mới đánh dấu đầy đủ. Nearby phải nghiệm thu với camera nằm trong radius nhưng ngoài trang đầu.

## 6. Cải tiến đề xuất

| Vấn đề có cơ sở | Thay đổi | Giá trị / nghiệm thu |
|---|---|---|
| Ngắt host vẫn thấy ảnh cuối, chưa thấy nhãn lỗi trong frame lượt 3 | Nhãn tuổi ảnh và lỗi tải | Người dùng nhận ra ảnh cũ; vượt ngưỡng freshness cấu hình phải hiện cảnh báo; giờ nhận/chụp phân biệt |
| Geocoder Android 9 lỗi khiến xác nhận không dùng được | Cho xác nhận tọa độ khi địa chỉ lỗi | Không phụ thuộc geocoder để xem camera; GPS denied + geocoder lỗi vẫn hoàn tất chọn điểm |
| Nearby có 89/90 dù bbox có thêm điểm trong radius | Metadata đầy đủ/phân trang, nhãn “Đã tải” | Không gây hiểu nhầm số lượng; test nhiều trang không bỏ sót hoặc trùng ID |
| LIVE kẹt loading do cleartext | HTTPS và thông báo lỗi có lối thoát | Player nguồn mẫu thành công; nguồn lỗi hết loading theo timeout, quay lại snapshot được |
| Ảnh khó quan sát trong khung ngang | Chế độ mở rộng giữ tỷ lệ | Xem rõ ảnh, thu gọn trở lại đúng camera/tab |

## 7. Điều kiện chuyển sang tích hợp thật

UI/logic có thể phát triển trên fixture. Trước tích hợp thật cần chốt provider được phép dùng, hợp đồng nguồn ảnh/stream, auth và hạn mức, radius/pagination, timestamp/cache. Capture request snapshot thực sự của app và phục hồi Dart caller là câu hỏi điều tra còn mở; không phải điều kiện phải sao chép nội bộ để xây app mới theo đặc tả độc lập.

Không tuyên bố đã hoàn tất reverse backend. Bước điều tra tiếp theo nếu cần tương thích nguồn gốc: capture TLS có mục tiêu trên đúng runtime artifact và đối chiếu thao tác/timestamp; chọn phương án theo công cụ khả dụng, không tự bỏ qua TLS hay cài engine mới chỉ để coi hợp đồng là đã xác minh.
