# Spec chức năng theo dõi camera giao thông

Ngày điều tra: 2026-10-14. Phạm vi: chức năng **Camera** của Cổng thông tin giao thông TP.HCM (`com.fts.notis`), không phải camera chụp ảnh của điện thoại.

> **Cập nhật qua lượt 5:** flow Xung quanh đã chạy đầu-cuối trên Google Android 13: chọn điểm thủ công → địa chỉ/nút xác nhận → 90 camera có khoảng cách → mở preview. Không cần grant GPS trong mẫu. Đã tách lỗi tìm chữ (route 404) và reverse geocoding trên emulator Android 9 (Service not Available). Restore Quan tâm, nhịp ~12 giây, background/resume và lỗi LIVE đã có bằng chứng trước đó. Snapshot HTTP app đầy đủ và Dart caller vẫn mở. Chi tiết: [lượt 5](camera-runtime-pass5.md), [lượt 4](camera-runtime-pass4.md), [lượt 3](camera-runtime-pass3.md), [API catalog](api-catalog.md).

## Cập nhật lượt 7

Đã capture HTTP plaintext thực sự của app cho bbox, nearby, snapshot, geocoding và bootstrap tenants/homepage; xem [camera-api-debug-pass7.md](camera-api-debug-pass7.md), REA HAR dẫn xuất `ev_e83f5decb7d2b302bacd89bc87d1f38766b2e49bc5870461f745effc816f0ca8`. Response tenants app chứa base camera/16 vùng. Header Bearer có ở list/search, snapshot mẫu không Authorization. Window thêm/xóa Quan tâm chỉ thấy GET ảnh, chưa xác nhận sync mọi account. Những câu “chưa capture snapshot HTTP app” ở phần lịch sử bên dưới được thay thế trong phạm vi method/path/header names/status đã thu; Dart handler/cache/pagination vẫn mở. Không tuyên bố toàn bộ API exhaustive.

## Cập nhật lượt 6

Đã tổng hợp [đặc tả tái dựng độc lập](rebuild-spec.md). Probe HTTP độc lập mới cho nearby 89 thay vì 90; `limit/page` thử không làm đổi kết quả, bbox có thêm 201 ID trong 5km không có ở nearby. Không hardcode 90 hoặc coi nearby đầy đủ trong radius. Snapshot probe trả JPEG nhưng chưa capture HTTP snapshot do app gửi, auth/cache/Dart caller vẫn chưa biết. Xem [camera-contract-pass6.md](camera-contract-pass6.md).

## 1. Trạng thái và phạm vi bằng chứng

Đây là đặc tả hành vi đã quan sát và yêu cầu tái dựng tương ứng. Đã tái hiện entry, bản đồ, preview, Quan tâm qua restart, khu vực, Xung quanh bằng chọn điểm thủ công, nhịp snapshot và một mẫu background/resume. Đã ghi nhánh ngắt host, lỗi LIVE cleartext, tìm chữ 404, Geocoder không sẵn sàng, cấp/từ chối quyền và dialog dịch vụ vị trí. Chưa xác minh snapshot HTTP app đầy đủ, cache contract, đăng nhập/sync, LIVE phát thành công, pagination hoặc mọi tác vụ nền.

Hai artifact được phân biệt:

| Artifact | Danh tính | Nguồn / giới hạn |
|---|---|---|
| `../base.apk` | SHA-256 `c94c209e4776fdf6b944e8ec3996f887312c97615e9ece0c8b16d6aad5d393f3`; package `com.fts.notis`; version `5.2.1`, code `502001` | APK workspace; `APKCube.txt` ghi nguồn apkcube.com, chưa xác minh nguồn phát hành/chữ ký |
| `../split_config.arm64_v8a.apk` | SHA-256 `851cb8600d72a0de1d7d6453e8b755abda063d970a20b17bbb87588ce52c77de` | Split workspace; chứa `lib/arm64-v8a/libapp.so`, SHA-256 `c7aac93feddc21001c7eb838747b3d0cf9cc764ff6e04edb94249e9d103d5900` |
| `../evidence/camera/runtime-base.apk` | SHA-256 `1cef9bf94c18d37a9d83eb7de97bff8e32644b9f2d56ea86107c625d615a0f54`; cùng package/version/code | Bản đã cài trên `emulator-5554`, Android 9, ABI x86_64, màn hình 1600×900; installer báo `com.aurora.store` |

Lượt 5 kéo cùng runtime APK set bằng REA rồi cài lên `emulator-5580`, Google Android 13 x86_64, 900×1600; base hash giữ nguyên. Môi trường mới không nhận prefs/token của emulator cũ. Bằng chứng và phạm vi khác biệt xem camera-runtime-pass5.

**Giới hạn:** cùng version không chứng minh cùng mã. Không gán hành vi runtime cho chính xác APK workspace; không gán literal ARM64 cho request thực tế của bản runtime. Screenshot REA chỉ xác thực một frame, không tự chứng minh toàn bộ chuỗi thao tác. Các chuỗi thao tác dưới đây là quan sát của lượt điều tra qua ADB.

## 2. Evidence index

Tên ngắn trong các mục sau trỏ tới file bằng chứng ở `../evidence/camera/`. Danh sách Evidence ID đầy đủ nằm trong [evidence-index.md](../evidence/camera/evidence-index.md).

| Tên ngắn | File / nội dung | Loại |
|---|---|---|
| P | `package.json`, Evidence `ev_72d266304784959edc6bb399b24de77ff60d106871f45b3f98e3026723aea04a` | Quan sát tĩnh REA/JADX |
| N | `native-extraction.json`, Evidence `ev_c9cf7fc7945dd4a8f7496364f61a04f25325687c3540d88aaf8b7cc3aabccb0a` | Quan sát tĩnh REA, trích xuất split |
| L | `native-string-candidates.json`; mỗi mục có file offset hex | Quan sát tĩnh bằng script; literal, không phải call graph |
| R | `runtime-package.json` | REA đọc metadata bản cài |
| HOME / ENTRY | `rea-main.json`, `rea-entry.json`, thư mục cùng tên chứa `screen.png` | Quan sát runtime |
| MAP / PREVIEW | `rea-map.json`, `rea-preview.json`, `ui-map.xml` | Quan sát runtime |
| EMPTY / ADD / REMOVE | `rea-favorites.json`, `rea-favorite-added.json`, `rea-favorite-removed.json` | Quan sát runtime |
| DETAIL / REFRESH | `rea-detail.json`, `rea-refresh.json`, `ui-detail.xml` | Quan sát runtime |
| NEAR | `rea-nearby.json`, `ui-nearby.xml` | Quan sát runtime |
| AREA / AREA-RESULT | `rea-area.json`, `rea-area-result.json`, `ui-area-result.xml` | Quan sát runtime |
| SEARCH | `rea-search-open.json`, `ui-search-open.xml` | Quan sát runtime |

## 3. Mục đích và flow người dùng

**Quan sát runtime — HOME, ENTRY:** trang chính có mục **Camera**. Bấm mục đó mở màn hình camera với tab **Bản đồ** được chọn trong lần thử. Thanh dưới có **Quan tâm / Bản đồ / Xung quanh**.

### F1. Xem camera từ bản đồ

1. Trang chính → Camera → Bản đồ.
2. Bản đồ có marker camera màu xanh lá; ở mức zoom rộng có marker kèm badge số. Ý nghĩa chính xác của badge chưa được kiểm tra bằng cách mở từng nhóm.
3. Bấm marker đơn tại vị trí camera **Cầu vượt nút giao thông Gò Dưa**.
4. Marker đang chọn chuyển xanh dương; khung ảnh xuất hiện ở phía trên. Khung có tên camera, tim đánh dấu, nút X và vòng đếm số.
5. Bấm X đóng khung ảnh, vẫn ở màn hình hiện tại.

**Quan sát runtime — MAP, PREVIEW, DETAIL, REFRESH và lượt 3:** đã mở/đóng khung; ảnh phương tiện thay đổi. Bộ đếm quan sát được có cả `11` và `0`; 18 XML mẫu cho hai chu kỳ ước lượng ~12.045 giây. Socket app gửi tới IP trùng DNS máy điều tra của api.notis.vn, có hai khoảng lặp ~11.845 và 12.006 giây. **Suy luận:** nhịp tải/refresh khoảng 12 giây trong mẫu. HTTP probe độc lập xác nhận nguồn JPEG snapshot; chưa giải mã path/method app hoặc xác minh phát stream. Xem `timing-summary-pass3.json` và báo cáo lượt 3.

### F2. Theo dõi camera quan tâm

1. Mở camera → bấm tim xám.
2. Chuyển tab Quan tâm: xuất hiện một dòng gồm thumbnail, tên camera và tim đỏ.
3. Bấm dòng camera: mở khung ảnh ngay trên danh sách; tim trong khung cũng đỏ.
4. Đóng khung → bấm tim đỏ ở dòng: camera biến mất; danh sách trở về phần hướng dẫn đánh dấu camera.

**Quan sát runtime — EMPTY, ADD, DETAIL, REMOVE và lượt 3:** thêm/xóa cập nhật qua hai màn hình; sau force-stop và mở process mới, camera xuất hiện lại trong Quan tâm (`rea-pass3-restored.json`). Key local `flutter.CameraCare_ttgt-tphcm` là string chứa JSON array object camera. Đã cleanup bằng UI về `[]`. Đồng bộ tài khoản, giới hạn và thứ tự chưa biết. Không có yêu cầu đăng nhập phát sinh trong chuỗi thử; không suy ra mọi trạng thái tài khoản.

### F3. Xem quanh một vị trí

**Quan sát runtime — lượt 5, cùng set APK trên emulator-5580 Android 13:**

1. Xung quanh → Tìm vị trí → Chọn vị trí trên bản đồ → từ chối prompt GPS → chọn/pan điểm thủ công.
2. Khi có địa chỉ reverse geocoding, hiện thẻ địa chỉ và nút Đồng ý hoạt động. Bấm xác nhận quay về Xung quanh, ô vị trí có địa chỉ đã chọn.
3. Hiện **Camera trong bán kính 5km**, **Kết quả tìm kiếm 90 camera**, grid hai cột ở màn portrait 900×1600. Thẻ có thumbnail, tên, tim, khoảng cách km; ảnh có thể tải sau text.
4. Mẫu đầu tăng khoảng cách 0.07 / 0.33 / 0.41 / 0.51 km. Chưa kết luận mọi kết quả đều sort hoặc đủ toàn bộ camera 5km/cap 90.
5. Bấm Phan Đăng Lưu - Hoàng Hoa Thám mở preview đúng camera, ảnh giao thông, tim, X và counter.

Bằng chứng: `rea-pass5-google-geocoded.json`, `rea-pass5-nearby-success.json`, `rea-pass5-nearby-open.json` và XML cùng flow; xem báo cáo lượt 5. FINE/COARSE vẫn denied trong mẫu thành công. Khả năng đổi bán kính chưa xác minh. Màn trắng ở lượt đầu không được coi là empty state chuẩn.

### F4. Chuyển khu vực

1. Bản đồ → Khu vực → bottom sheet danh sách.
2. Các mục nhìn thấy: Đường hoa Nguyễn Huệ; Đường Trường Chinh - Tân Kỳ Tân Quý; Ngã sáu Dân chủ; Ngã 6 Gò Vấp. Đây chỉ là phần nhìn thấy, không phải danh sách đầy đủ.
3. Chọn Đường hoa Nguyễn Huệ: sheet đóng, ô trên cùng đổi sang tên khu vực, bản đồ chuyển đến Nguyễn Huệ, có pin đỏ và camera xung quanh.

**Quan sát runtime — AREA, AREA-RESULT và storage lượt 2:** đã tái hiện kết quả chọn khu vực. Cấu hình tenant lưu `area-camera` gồm 16 object `{name, coordinates:[lng,lat]}`; chưa xác định endpoint/cơ chế cập nhật cấu hình.

### F5. Tìm địa điểm

**Quan sát runtime — SEARCH và lượt 3:** có ô Nhập địa điểm, Vị trí hiện tại, Chọn vị trí trên bản đồ, Địa chỉ của tôi, Thêm và Lịch sử tìm kiếm. Query `Go Dua` mở Kết quả tìm kiếm nhưng không có dòng kết quả trong frame thu được. Chọn vị trí trên bản đồ hiện prompt vị trí; chọn Không vẫn vào bản đồ và bấm được điểm tím, nhưng nút Đồng ý mờ và chưa xác nhận vị trí thành công. Chưa xác minh provider, debounce, lịch sử, lưu địa chỉ hoặc chọn kết quả.

**Bổ sung lượt 4–5:** app prompt Đồng ý dẫn tới Android dialog quyền; cấp quyền có thể còn hiện dialog dịch vụ/độ chính xác. Với chọn thủ công, mẫu Android 13 vẫn hoàn tất khi GPS denied. Log app xác nhận lần tìm chữ `Go Dua` đi cùng response 404 Route not found tại `/ttgt-tphcm/routing/geocoding`. Reverse geocoding là nhánh riêng: native `q3.r.onMethodCall` case `placemarkFromCoordinates`; Android 9 gọi Geocoder sync và gặp Service not Available, Android ≥13 dùng overload listener theo REA. Thành công chọn điểm đã xác nhận bằng UI trên Android 13. Không quy lỗi route 404 cho GPS, hoặc coi `url-api-search-address=null` là nguyên nhân chắc chắn.

### F6. Chuyển sang LIVE

**Quan sát runtime — lượt 4:** preview Võ Văn Kiệt - Ký Con có nút LIVE riêng trên hàng tên. Bấm LIVE → spinner/Đang tải. Hook ghi attempted GET `http://camera.thongtingiaothong.vn/s/56de42f611f398ec0c481287/index.m3u8` qua caller Java `p1.p.p`; ExoPlayer/Flutter log lỗi nguồn và cleartext HTTP not permitted. Manifest đúng runtime APK có `usesCleartextTraffic=false`. Chưa phát video thành công hoặc tải được playlist. Không đồng nhất nút LIVE này với biểu tượng camera nổi bên phải bản đồ.

### F7. Snapshot khi app ở nền

**Quan sát runtime — lượt 4:** cửa sổ 18 giây foreground có hai write tới host camera, 30 giây sau Home không có write trong hooks, resume gửi lại sau khoảng 0,052 giây và tiếp tục nhịp ~12 giây. **Suy luận giới hạn:** lịch tải ảnh tạm dừng/tiếp tục theo lifecycle trong mẫu; chưa có Dart handler hoặc chứng minh mọi host/tác vụ đều dừng.

## 4. Yêu cầu tái dựng và tiêu chí nghiệm thu

Các yêu cầu bên dưới là **đặc tả đề xuất từ hành vi**; không phải khẳng định cấu trúc code hay backend của app gốc. Mục có bằng chứng thiếu ghi riêng phạm vi nghiệm thu cần quyết định.

| ID | Yêu cầu | Tiêu chí nghiệm thu | Cơ sở |
|---|---|---|---|
| CAM-01 | Có entry Camera và ba tab Quan tâm/Bản đồ/Xung quanh | Từ trang chính mở được chức năng; chuyển qua cả ba tab | HOME, ENTRY |
| CAM-02 | Hiển thị camera theo tọa độ trên bản đồ | Với dữ liệu mẫu có camera ở hai tọa độ, marker xuất hiện đúng vị trí; chọn marker mở đúng camera | MAP, PREVIEW; tọa độ/schema là thiết kế riêng |
| CAM-03 | Khung xem có ảnh, tên, tim, X, trạng thái làm mới | Mở camera A phải hiển thị tên/ảnh A; đóng X quay lại màn đang xem | PREVIEW, DETAIL |
| CAM-04 | Làm mới ảnh có vòng đếm | Với provider snapshot mẫu, interval mặc định đề xuất 12 giây theo mẫu đo; cập nhật ảnh và reset đếm; interval cấu hình được, xử lý provider thay đổi nhịp | REFRESH, timing-summary-pass3; không coi 12 giây là hợp đồng mọi camera |
| CAM-05 | Thêm/xóa và lưu bền Quan tâm | Thêm từ preview có đúng một mục; force-stop/mở lại vẫn có tên/thumbnail/tim; xóa thì mục biến mất và local storage cập nhật | ADD, DETAIL, REMOVE, rea-pass3-restored |
| CAM-06 | Danh sách Quan tâm rỗng có hướng dẫn | Khi không còn mục, hiển thị hướng dẫn cách đánh dấu | EMPTY, REMOVE |
| CAM-07 | Chọn khu vực để di chuyển bản đồ | Chọn một khu vực thì đóng sheet, cập nhật tên và tâm bản đồ; camera tương ứng xuất hiện | AREA, AREA-RESULT |
| CAM-08 | Tìm camera Xung quanh từ điểm chọn | Chọn điểm/xác nhận cập nhật địa chỉ; có số kết quả, thumbnail/tên/tim/khoảng cách km; mở thẻ ra đúng preview; xử lý ảnh tải chậm | Flow đầu-cuối lượt 5; không hardcode 90 hoặc cam kết cap khi chưa có contract |
| CAM-09 | Tìm địa điểm phục vụ chọn vùng xem | Có ô nhập, vị trí hiện tại, chọn trên bản đồ; việc trả kết quả và dịch chuyển bản đồ là yêu cầu đề xuất cần xác nhận nguồn geocoding | SEARCH; chưa tái hiện kết quả |
| CAM-10 | Nhận biết ảnh cũ khi refresh lỗi | Với backend bị ngắt, giữ ảnh cuối nhưng có nhãn tuổi ảnh/lỗi; sau kết nối lại thì tải tiếp | Cải tiến từ phép thử ngắt host lượt 3; nhãn lỗi chưa thấy ở app gốc |
| CAM-11 | Chọn điểm thủ công khi không cấp GPS; xử lý geocoding lỗi | GPS denied vẫn chọn/xác nhận được khi geocoder trả địa chỉ; nếu geocoder lỗi phải có thông báo/thử lại và giải thích nút disabled | Nhánh thành công Android 13 và lỗi Android 9 lượt 5; thông báo lỗi rõ là cải tiến |
| CAM-12 | Dừng/tiếp tục lịch snapshot theo lifecycle | Backend stub không nhận polling khi app ở nền; resume tải ảnh và chạy lại interval; không tạo timer trùng | Mẫu socket lifecycle lượt 4; tiêu chí chất lượng cho app mới |
| CAM-13 | Phân biệt snapshot/LIVE và xử lý lỗi media | Camera có nguồn LIVE hợp lệ mới hiện lối mở; trạng thái loading có timeout/error và quay về snapshot được; nguồn HTTPS được cấp quyền | UI LIVE, attempted GET và lỗi cleartext lượt 4; chưa phát thành công |

## 5. Mô hình dữ liệu và trạng thái đề xuất

**Thiết kế đề xuất**, không phải response schema đã reverse được:

- `Camera`: phân biệt `_id` khóa nguồn và `id` mã hiển thị; `name`, tọa độ từ `[lng,lat]`, nguồn ảnh/stream được cấp quyền; field nullable/vắng phải được xử lý. `imageTs` chưa tự coi là thời điểm chụp.
- `CameraFavorite`: lưu bền local theo tenant; có thể chọn lưu ID kèm metadata cache trong app mới. App gốc lưu object camera; đồng bộ là câu hỏi sản phẩm còn mở.
- `CameraArea`: `id`, `name`, tâm và vùng bao tùy provider.
- State màn hình: `activeTab`, `mapViewport`, `selectedCameraId`, `favorites`, `selectedLocation`, `selectedArea`, `refreshCountdown`, `imageState`.

Máy trạng thái đề xuất cho khung ảnh: Đóng → Đang tải → Có ảnh hoặc Lỗi; khi làm mới vẫn giữ ảnh cũ và cho biết thời điểm nhận ảnh. Đóng khung hoặc app vào background phải dừng timer/request của khung. Đây là yêu cầu chất lượng cho app mới, chưa xác minh lifecycle app gốc.

## 6. API và tầng xử lý

**Quan sát tĩnh — P:** manifest có Flutter embedding. **Quan sát tĩnh — N:** split chứa `libapp.so` và `libflutter.so`. **Suy luận:** phần chức năng camera có thể nằm trong Dart AOT; JADX DEX không đủ để khôi phục flow nghiệp vụ này.

REA `search_android_classes` đã tìm case-sensitive substring `Camera` trên 16.271 class: 12 kết quả chủ yếu là Android camera/barcode/picture libraries; không tìm thấy tên class nghiệp vụ rõ ràng trong phạm vi truy vấn này. Điều đó không chứng minh không có code camera trong DEX. Chưa có class/method/caller Dart được xác nhận.

Các literal đáng theo tiếp trong `libapp.so`: `cameras/bybbox?lat1=` (offset `0xbc85f`), `cameras?lat=` (`0xc1cbb`), `/transit/cameras?routeId=` (`0x82a9c`), `url-api-camera` (`0x135ae0`), `area-camera` (`0x16a586`), `CameraCare_` (`0x7c61b`), `cameraId` (`0xcd10d`), `cameraName` (`0xd4a38`). **Không** ghép host với path hoặc suy ra caller từ việc các chuỗi cùng nằm trong một binary. Chi tiết: [api-catalog.md](api-catalog.md).

## 7. Cải tiến đề xuất cho ứng dụng mới

Các mục này chưa được người dùng chọn triển khai và không phải hành vi app gốc đã xác minh.

| Vấn đề | Thay đổi | Giá trị | Tiêu chí nghiệm thu đề xuất |
|---|---|---|---|
| Người xem khó biết ảnh có còn mới | Hiển thị giờ chụp nếu provider có, nếu không ghi rõ giờ nhận; đánh dấu ảnh cũ | Tránh hiểu nhầm dữ liệu cũ là giao thông hiện tại | Khi ảnh không cập nhật quá ngưỡng cấu hình, có nhãn ảnh cũ; không tự nhận giờ nhận là giờ chụp |
| Khung ảnh rất thấp ở màn ngang trong phiên thử | Khung xem có chế độ mở rộng, giữ đúng tỷ lệ ảnh | Dễ quan sát chi tiết | Có thể mở rộng/thu gọn; không kéo méo ảnh |
| Tab Xung quanh trắng không giải thích trong phiên thử | Phân biệt tải, rỗng, lỗi mạng và thiếu quyền vị trí | Người dùng biết cách tiếp tục | Mỗi tình huống có thông báo và hành động thử lại/chọn vị trí |
| Làm mới nhiều ảnh dễ tốn dữ liệu | Dừng khi background; chỉ refresh camera đang xem; interval cấu hình | Giảm pin và lưu lượng | Không phát request refresh khi khung đóng/app background trong kiểm thử |

## 8. Phần còn phải xác minh

1. Network capture khi vào Camera, đổi viewport, chọn khu vực, mở ảnh và bấm tim: host, method, path đầy đủ, headers xác thực (che bí mật), schema response, cache, lỗi.
2. Phân tích AOT/hook có mục tiêu để nối snapshot UI → Dart handler → data provider. Caller Java media và geocoding đã có bằng chứng riêng, không coi là đã khôi phục tầng Dart.
3. Mở rộng: Quan tâm theo đăng nhập/offline; vị trí hiện tại từ GPS (chọn thủ công đã thành công khi denied); mất mạng toàn bộ/camera hỏng; nhiều camera và lifecycle trên các thiết bị khác (đã đo một camera/background 30 giây).
4. Đã thử nút LIVE riêng của camera Ký Con và xác định attempted GET bị cleartext policy chặn. Còn mở: LIVE phát thành công, playlist/codec, fullscreen, chuyển chế độ và vai trò chính xác của biểu tượng camera nổi trên bản đồ.
5. Đồng nhất artifact runtime với bộ APK workspace, hoặc điều tra riêng từng artifact trước khi kết luận tương đương.

**Kết luận phạm vi:** đủ bằng chứng cho spec UI/flow chính của bản đồ, preview, Quan tâm, Xung quanh bằng chọn điểm thủ công; có nhánh lỗi tìm chữ, geocoder, network và LIVE. Chưa đủ cho hợp đồng tích hợp backend đầy đủ hoặc mô tả nội bộ Dart. App mới cần nguồn camera/backend được cho phép sử dụng; việc tìm thấy endpoint không xác nhận quyền hoặc khả năng tái sử dụng.
