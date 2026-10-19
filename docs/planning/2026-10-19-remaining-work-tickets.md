# Đề xuất ticket phần việc còn lại — 2026-10-19

**Trạng thái: T01–T08 đã được duyệt và tạo trên GitHub ngày 2026-10-19. T09–T25 tiếp tục là bản nháp, chưa duyệt và chưa tạo issue.**

Cơ sở rà soát: repository tại commit `8c56481`; đặc tả/backlog và các báo cáo nghiệm thu hiện có. Mã T01–T25 là mã tham chiếu trong tài liệu; số issue thực tế của đợt A nằm trong bảng dưới.

Người dùng đã duyệt **T01–T08 trước**, giữ nguyên cách chia và phụ thuộc để khép chất lượng A1 và chuẩn bị vận hành. T09–T25 vẫn là các lựa chọn roadmap; duyệt danh sách không đồng nghĩa đã chốt mọi hợp đồng kỹ thuật hay đã cho phép triển khai dịch vụ trả phí.

## Ticket đã xuất lên GitHub

| Mã đề xuất | Issue GitHub | Nhãn lúc tạo | Bị chặn bởi |
|---|---|---|---|
| T01 | [#1](https://github.com/longkunz/lovi-etown/issues/1) | `ready-for-agent` | Không |
| T02 | [#2](https://github.com/longkunz/lovi-etown/issues/2) | `ready-for-agent` | Không |
| T03 | [#3](https://github.com/longkunz/lovi-etown/issues/3) | `ready-for-agent` | #1, #2 |
| T04 | [#4](https://github.com/longkunz/lovi-etown/issues/4) | `ready-for-agent` | #1, #2 |
| T05 | [#5](https://github.com/longkunz/lovi-etown/issues/5) | `ready-for-agent` | Không; cần thiết bị tương ứng |
| T06 | [#6](https://github.com/longkunz/lovi-etown/issues/6) | `needs-info` | Không; cần chốt spec |
| T07 | [#7](https://github.com/longkunz/lovi-etown/issues/7) | `needs-info` | #6 |
| T08 | [#8](https://github.com/longkunz/lovi-etown/issues/8) | `needs-info` | #7 |

Sáu cạnh chặn đã được thiết lập bằng quan hệ issue dependencies của GitHub, đồng thời có trong nội dung từng issue. Nhãn là trạng thái lúc xuất; dùng GitHub làm nguồn trạng thái thực thi về sau. T03/T04 chỉ được triển khai khi blocker đã hoàn tất; T04/T05 cần tài nguyên nền tảng phù hợp. T06–T08 chờ spec theo quy tắc dưới đây.

## Cơ sở và phần đã hoàn thành

- [Hiện trạng dự án](../project-status.md): 49 backend tests và 45 Flutter unit/widget tests đã PASS ngày 2026-10-19. Lượt rà soát này không chạy lại test hoặc tạo bằng chứng thiết bị mới.
- [Nghiệm thu Mobile A1](../ui/mobile-a1-verification.md): đã xử lý ST1–ST4, SP1–SP10; báo cáo có debug APK, nhưng chưa smoke trên Android/emulator tại thời điểm nghiệm thu. Không có bằng chứng nghiệm thu iOS trong báo cáo này.
- [Nghiệm thu backend](../../backend/docs/verification.md): đã có smoke Notis từ backend, catalog/search/district/playback/snapshot/304. Điều này không thay thế smoke từ app trên thiết bị hoặc từ môi trường HTTPS triển khai mới.
- [Đặc tả Mobile A1](../superpowers/specs/2026-10-15-camera-mobile-a1-design.md) và [plan](../superpowers/plans/2026-10-16-camera-mobile-a1.md): còn cần đối soát thực tế về lifecycle, thiết bị, accessibility, renderer và hiệu năng. Checkbox cũ chưa được đánh dấu không tự chứng minh thiếu implementation.
- [Đặc tả tái dựng](../rebuild-spec.md), [backlog IMP-01–08](../improvement-backlog.md), [stack review](../stack-review.md), [nhật ký quyết định](../superpowers/brainstorming-status.md): phân biệt phạm vi A1 đã chọn với đề xuất và mục tiêu dài hạn. Giữ Android/iOS, TP.HCM trước, Vietmap đã chọn và nguồn Notis hiện có; không đề nghị quyết định lại các lựa chọn này.

Không tạo lại ticket cho tìm kiếm không dấu cơ bản, phân trang/dedupe, favorites local, ETag/304, cùng-origin/redirect guard và bounded snapshot cache đã có bằng chứng. T01–T02 kiểm tra các nhánh còn rủi ro cụ thể, không mở lại toàn bộ findings lịch sử.

## Quy tắc trạng thái và xuất ticket

- Mỗi ticket triển khai là một luồng có đầu ra kiểm chứng được; không chia riêng thành ticket database/API/UI cho cùng một hành vi.
- Các ticket chốt quyết định T06, T10, T15, T21, T24 cần đầu vào/phê duyệt sản phẩm, dự kiến dùng `needs-info` cho tới khi chốt. Chúng tạo quyết định và đặc tả, không được đóng chỉ bằng việc ghi lại câu hỏi.
- T07–T08 và các ticket roadmap phụ thuộc quyết định là bản dự kiến. Trước khi gán `ready-for-agent`, hoàn thiện spec bằng `to-spec`, xác nhận phạm vi/seam kiểm thử, rồi điều chỉnh ticket bằng `to-tickets`. Chưa gọi chúng là agent-ready chỉ vì đã có nhãn.
- T01–T05 đã được gắn `ready-for-agent` sau khi duyệt phạm vi. Phụ thuộc công việc dùng quan hệ blocking trên GitHub; thiết bị/macOS/tài khoản/môi trường là điều kiện tài nguyên, được ghi riêng.
- Không tạo spec/ticket giả cho việc đã làm, không mặc định thêm đăng nhập, đồng bộ tài khoản hoặc các tỉnh khác vào A1. Không tự đóng hay sửa issue cha khi xuất ticket.

## Đợt A — ưu tiên khép A1 và chuẩn bị vận hành

### 1. T01 — Giữ ảnh tốt khi snapshot mới không giải mã được

**Ưu tiên:** P1. **Blocked by:** Không.

**Đầu ra:** Người dùng vẫn xem được ảnh hợp lệ cuối cùng khi server trả payload có header ảnh nhưng nội dung hỏng. Phạm vi bổ sung sâu hơn kiểm tra magic bytes đã có.

**Nghiệm thu:**
- [ ] Có regression test tái hiện payload JPEG/PNG/WebP đủ dài và có magic bytes nhưng không decode được, sau một frame hợp lệ; xác nhận test đỏ trước khi sửa.
- [ ] Frame lỗi không thay last-good frame hoặc đi vào cache dùng chung; preview/viewer/thumbnail giữ đúng camera. Ảnh hợp lệ vẫn hiển thị, 304 giữ bytes và giới hạn 2 MiB vẫn được áp dụng.
- [ ] Báo cáo kết quả targeted tests và full suite; nếu giả thuyết không tái hiện, ghi bằng chứng và sửa phạm vi ticket trước khi triển khai.

### 2. T02 — Preview báo lỗi và phục hồi đúng sau mất mạng

**Ưu tiên:** P1. **Blocked by:** Không.

**Đầu ra:** Lỗi mở camera, lấy descriptor hoặc refresh có thông báo phù hợp và lối phục hồi; giữ ảnh tốt khi có. Kế thừa backoff/lifecycle đã có, sửa các nhánh còn thiếu thay vì thay cả cơ chế polling.

**Nghiệm thu:**
- [ ] Tái hiện/test riêng lỗi detail lần đầu, lỗi descriptor, lỗi refresh khi còn ảnh và mạng phục hồi; backoff tự động cho lỗi tạm thời thực hiện lại đúng bước detail/descriptor còn thiếu, không kẹt vì chưa có snapshot endpoint. Retry chủ động của người dùng vẫn hoạt động.
- [ ] Lỗi refresh được nhận biết cả trước ngưỡng ảnh cũ; không gọi lỗi mạng là camera offline, không suy giờ chụp từ giờ tải. Giữ sheet tối giản, không thêm thanh nút hoặc text thời gian đã bị loại khỏi A1.
- [ ] 401/403/404/422 không retry vô hạn; 429 tôn trọng Retry-After; đóng/background hủy tác vụ, resume chỉ có một chuỗi. Có fake-clock/transport tests.

### 3. T03 — Nghiệm thu luồng A1 trên Android

**Ưu tiên:** P1. **Blocked by:** T01, T02 để nghiệm thu bản đã sửa; có thể thu baseline trước.

**Đầu ra:** Có bằng chứng app thực sự hoàn tất luồng camera trên thiết bị/emulator, vượt ra ngoài widget harness.

**Nghiệm thu:**
- [ ] Chạy integration fixture và debug APK: tìm/lọc/đổi mode → Quan tâm → sheet → zoom/xoay → quay lại đúng ngữ cảnh; restart giữ Quan tâm.
- [ ] Log đã che thông tin nhạy cảm chứng minh dismiss/background dừng request, resume không nhân polling; lỗi mạng có đường phục hồi.
- [ ] Smoke từ app qua backend với một camera thực đang có trong catalog: list/detail/ảnh/304 nếu nguồn cho phép; ghi thiết bị, OS, SDK, commit, screenshot và kết quả từng ca. Không đồng bộ toàn TP.HCM chỉ để smoke.

### 4. T04 — Build và nghiệm thu cùng luồng A1 trên iOS

**Ưu tiên:** P1. **Blocked by:** T01, T02. **Tài nguyên:** macOS/Xcode và simulator/thiết bị phù hợp.

**Đầu ra:** Có bằng chứng iOS riêng; phát hiện và sửa khác biệt nền tảng của cùng luồng camera.

**Nghiệm thu:**
- [ ] Build simulator thành công, chạy fixture trên iPhone; xác minh sheet/viewer, xoay màn hình, lifecycle và favorites sau restart.
- [ ] Chạy ca mạng thực qua backend được cấu hình, phân biệt lỗi cấu hình/mạng với lỗi nguồn; kiểm tra viewport iPad khi có môi trường hỗ trợ.
- [ ] Lưu lệnh, môi trường và kết quả; mọi phần thiếu thiết bị hoặc chưa chạy được ghi rõ, không suy PASS iOS từ Android/unit tests.

### 5. T05 — Kiểm chứng Liquid Glass, khả năng tiếp cận và hiệu năng trên thiết bị

**Ưu tiên:** P1. **Blocked by:** Không; có thể thực hiện song song nghiệm thu luồng. **Tài nguyên:** thiết bị Android; macOS/thiết bị iOS cho phần iOS.

**Đầu ra:** Camera vẫn dễ đọc, thao tác được và không tăng tài nguyên liên tục khi cuộn/xem ảnh.

**Nghiệm thu:**
- [ ] Kiểm tra viewport 320/390px, font scale 2, light/dark, focus modal, TalkBack/VoiceOver, labels và reduced motion; ghi rõ platform đã chạy, sửa các lỗi liên quan.
- [ ] Đo frame timing và bộ nhớ khi cuộn, preview và 20 lần mở/đóng; đối chiếu mục tiêu 16,7 ms/frame trên thiết bị 60 Hz, điều chỉnh chất lượng khi có bằng chứng cần thiết.
- [ ] Không shader exception hoặc mất nội dung; lưu screenshot/profile/device và lỗi còn mở. Không dùng golden giống HTML làm bằng chứng chất lượng renderer.

### 6. T06 — Chốt hợp đồng truy cập và vận hành bản dùng thử A1

**Ưu tiên:** P1. **Blocked by:** Không. **Loại:** quyết định/đặc tả, dự kiến `needs-info`.

**Đầu ra:** Một spec đủ để triển khai bản dùng thử công khai mà không coi reader key nhúng trong mobile là bí mật.

**Nghiệm thu:**
- [ ] Chốt hành vi đọc camera công khai, kiểm soát lạm dụng/rate limit, phân tách quyền quản trị, xoay cấu hình và lỗi client cần xử lý; không tự thêm yêu cầu đăng nhập.
- [ ] Chốt môi trường đích, domain/TLS, phạm vi phát hành thử, retention log/backup, tải mục tiêu và ngân sách theo giả định có thể đo; giữ mục tiêu dưới 1 triệu đồng/tháng là mục tiêu cần kiểm chứng.
- [ ] Spec ghi lựa chọn, đánh đổi, tiêu chí vận hành và các seam kiểm thử được duyệt. T07–T08 được rà lại theo quyết định này trước khi đánh dấu sẵn sàng.

### 7. T07 — Truy cập camera dùng thử với kiểm soát lạm dụng đã chốt

**Ưu tiên:** P1. **Blocked by:** T06. **Trạng thái:** chờ spec T06.

**Đầu ra:** App đọc danh sách/ảnh qua backend theo chính sách truy cập mới; người dùng nhận lỗi có thể xử lý khi hết hạn hoặc bị giới hạn.

**Nghiệm thu:**
- [ ] Luồng list → detail → snapshot chạy theo hợp đồng T06; các ca không được phép/hết hạn/giới hạn trả hành vi xác định ở API và UI.
- [ ] Quyền quản trị không đi vào app; upstream secret không lọt qua descriptor, redirect hay log; có ca lạm dụng và regression tests cho same-origin/ETag/lifecycle.

### 8. T08 — Môi trường HTTPS chạy được, sao lưu và khôi phục kiểm chứng được

**Ưu tiên:** P1. **Blocked by:** T07. **Tài nguyên:** môi trường/domain/cấu hình từ T06 và quyền triển khai tương ứng.

**Đầu ra:** Có backend dùng thử qua HTTPS, luồng camera chạy từ app, và runbook phục hồi dữ liệu/dịch vụ.

**Nghiệm thu:**
- [ ] Migration → import giới hạn theo cấu hình → camera từ app → snapshot/304 hoạt động qua HTTPS; cấu hình triển khai dùng giá trị riêng, không dùng secret mẫu.
- [ ] Thử restart/rollback; khôi phục một backup vào DB tách biệt và so sánh catalog/ID. Log, health và đo tải nhỏ đủ nhận biết lỗi và ước tính traffic/chi phí theo tải T06.
- [ ] Ghi rõ phạm vi smoke Android/iOS trên môi trường này; cập nhật runbook, kiểm thử và các giới hạn. Ticket không mặc định gồm phát hành App Store/Google Play.

## Đợt B — cải tiến offline và vị trí, cần chọn phạm vi

### 9. T09 — Duyệt metadata camera đã tải khi mất mạng và mở lại app

**Cơ sở:** IMP-07. **Blocked by:** Không. **Điều kiện:** người dùng chọn cải tiến này.

**Đầu ra:** Sau một lần tải thành công, người dùng vẫn tìm/lọc metadata đã lưu và mở Quan tâm khi offline.

**Nghiệm thu:**
- [ ] Cache bền có version/TTL/giới hạn; cold start offline dùng dữ liệu đã lưu, lỗi cache có đường phục hồi; query/version khác không trộn trang.
- [ ] Có nhãn cache/cũ và phạm vi dữ liệu đã tải, không nói đã có toàn bộ catalog hoặc đang phát LIVE. Khi online refresh có giới hạn và không mất Quan tâm; không mở rộng sang lưu video/album ảnh offline.

### 10. T10 — Chốt đặc tả Vietmap, viewport và lựa chọn vị trí

**Cơ sở:** R-02, R-06–R-10. **Blocked by:** Không. **Loại:** quyết định/đặc tả, dự kiến `needs-info`.

**Đầu ra:** Spec cho các lát T11–T14, giữ Vietmap đã được chọn và một màn Camera hiện có.

**Nghiệm thu:**
- [ ] Chốt phiên bản/hợp đồng provider được dùng, quota/cache, bảo vệ credential, contract bbox/radius/phân trang và cách phối hợp list/map/điểm chọn.
- [ ] Chốt contract geocoding và geometry tuyến cho mục tiêu sau; định nghĩa fallback tọa độ, camera thiếu tọa độ, kiểm thử biên 5 km và response cũ. Không quay lại ba tab của dự thảo sơ bộ nếu chưa được duyệt.

### 11. T11 — Xem camera trong viewport bản đồ

**Blocked by:** T10. **Đầu ra:** Pan/zoom bản đồ lấy camera đúng vùng, chạm marker mở snapshot đúng ID.

**Nghiệm thu:**
- [ ] Query viewport có bounds/phân trang xác định, không bỏ sót hoặc trùng theo contract; response viewport cũ không ghi đè viewport mới.
- [ ] Mở/đóng sheet giữ vị trí bản đồ và Quan tâm; camera thiếu tọa độ vẫn dùng được trong danh sách; có fixture/API/widget tests.

### 12. T12 — Chọn điểm thủ công và xem camera trong bán kính 5 km

**Blocked by:** T11. **Đầu ra:** Chọn/xác nhận điểm trên bản đồ → danh sách camera gần điểm → snapshot.

**Nghiệm thu:**
- [ ] GPS denied hoặc geocoder lỗi vẫn xác nhận bằng tọa độ; radius tính mét, khoảng cách/sắp xếp và phân trang nhất quán.
- [ ] Có ca camera ở biên, nằm ngoài trang đầu, cùng tên khác ID và thiếu tọa độ. Chỉ nói đầy đủ khi contract bảo đảm; không dùng số camera mẫu làm cap.

### 13. T13 — Dùng vị trí hiện tại cho danh sách Xung quanh

**Blocked by:** T12. **Đầu ra:** Người dùng chủ động yêu cầu vị trí, chọn được camera gần mình hoặc quay sang điểm thủ công.

**Nghiệm thu:**
- [ ] Chỉ xin quyền khi thao tác; denied/permanently denied, dịch vụ tắt, timeout và vị trí thiếu độ chính xác có hướng xử lý.
- [ ] Ghi độ mới/độ chính xác vị trí; không gọi vị trí cũ là hiện tại, không tự bật tracking nền. Có thử riêng Android/iOS.

### 14. T14 — Tìm địa điểm và xem camera quanh kết quả

**Blocked by:** T12. **Đầu ra:** Tìm/chọn địa điểm → cập nhật điểm đã chọn → camera gần đó → snapshot.

**Nghiệm thu:**
- [ ] Debounce/bỏ response cũ; không có kết quả, provider lỗi và 429 có trạng thái riêng; giữ điểm cũ khi tìm lỗi.
- [ ] Credential/quota tuân theo T10; tên địa chỉ có thể thiếu mà luồng chọn điểm không bị chặn.

## Đợt C — thời tiết và ba phạm vi cảnh báo

### 15. T15 — Chốt nguồn thời tiết và hợp đồng cảnh báo/quyền riêng tư

**Cơ sở:** mục tiêu trong nhật ký quyết định, IMP-08 có điều kiện. **Blocked by:** Không. **Loại:** quyết định/đặc tả, dự kiến `needs-info`.

**Đầu ra:** Spec duyệt được cho nguồn dữ liệu, event, lịch xử lý, push và ba phạm vi đã ghi nhận.

**Nghiệm thu:**
- [ ] Có nguồn/quota/độ phủ/tần suất/chi phí khả thi, quy tắc cảnh báo mưa/nguy cơ, thời hạn sự kiện và dedupe; ghi rõ chưa thể công bố ngập nếu thiếu nguồn ngập đã xác minh.
- [ ] Chốt installation identity không bắt buộc login, consent/retention/xóa dữ liệu, FCM/APNs, freshness vị trí và giới hạn chạy nền. Xuất spec và tách lại T16–T20 nếu vượt một phiên triển khai.

### 16. T16 — Xem thông tin mưa/thời tiết cho khu vực chọn

**Blocked by:** T15. **Đầu ra:** Chọn một khu vực đã chốt, có thể qua bộ chọn khu vực hiện có → xem dữ liệu thời tiết có nguồn và thời điểm cập nhật. Không bắt buộc phải có bản đồ.

**Nghiệm thu:**
- [ ] Adapter/backend/UI phục vụ một loại thông tin đã chốt; cache theo khu vực và phân biệt lỗi provider, dữ liệu cũ, không dữ liệu.
- [ ] Không suy trạng thái ngập từ tên camera hoặc ảnh; có fixture cũ/thiếu dữ liệu, quota lỗi và test đầu-cuối.

### 17. T17 — Đăng ký và nhận cảnh báo mưa cho một khu vực lưu

**Blocked by:** T16. **Đầu ra:** Lưu một khu vực → bật một loại cảnh báo đã chốt → nhận push → mở đúng ngữ cảnh trong app.

**Nghiệm thu:**
- [ ] Có đăng ký thiết bị/quyền thông báo, event/outbox bền và retry; restart worker không làm mất hoặc gửi trùng cùng sự kiện ngoài chính sách.
- [ ] Hủy đăng ký/đổi token được xử lý; thử quyền denied, provider lỗi và push lỗi. Có bằng chứng delivery trên Android và iOS được cấu hình, giới hạn rõ khi thiếu tài nguyên.

### 18. T18 — Cảnh báo theo vị trí hiện tại còn hiệu lực

**Blocked by:** T13, T17. **Đầu ra:** Người dùng chọn nhận cảnh báo theo vị trí được cập nhật theo consent.

**Nghiệm thu:**
- [ ] Vị trí hết freshness không tiếp tục được gọi là hiện tại; cập nhật, thu hồi consent và xóa dữ liệu có hành vi xác định.
- [ ] Kiểm thử chuyển vị trí, restart, dedupe và giới hạn nền hai OS; không hứa theo dõi liên tục khi app đóng nếu chưa có phép thử.

### 19. T19 — Lưu tuyến thường đi bằng geometry thực

**Blocked by:** T11. **Đầu ra:** Chọn điểm đầu/cuối trên bản đồ theo spec → xem geometry từ provider hợp lệ → xác nhận lưu tuyến.

**Nghiệm thu:**
- [ ] Lưu/sửa/xóa tuyến, hiển thị lại sau restart; geometry đúng tuyến đã xác nhận, không dùng đoạn thẳng thay đường đi.
- [ ] Provider lỗi hoặc không có tuyến không lưu dữ liệu giả; quota/retention tuân theo contract T10. Ticket này chưa bao gồm cảnh báo.

### 20. T20 — Nhận cảnh báo mưa dọc tuyến đã lưu

**Blocked by:** T17, T19. **Đầu ra:** Đăng ký cảnh báo cho tuyến → đối chiếu hành lang tuyến với sự kiện → push mở đúng tuyến.

**Nghiệm thu:**
- [ ] Quy tắc corridor, thời gian và mức độ cảnh báo theo spec; test sự kiện trong/ngoài biên, tuyến chồng nhau và sự kiện hết hạn.
- [ ] Sửa/xóa tuyến cập nhật subscription; không gọi routing lại mỗi tick; retry/dedupe không spam người dùng.

## Đợt D — quảng cáo nhẹ và VIP

### 21. T21 — Chốt chính sách quảng cáo và quyền lợi VIP

**Cơ sở:** IMP-02, mục tiêu doanh thu đã ghi nhận. **Blocked by:** Không. **Loại:** quyết định/đặc tả, dự kiến `needs-info`.

**Đầu ra:** Spec về vị trí/tần suất quảng cáo, lượt xem đầu, VIP bỏ quảng cáo, restore và hành vi lỗi.

**Nghiệm thu:**
- [ ] Chốt thời điểm hiển thị và trường hợp không được chặn luồng xem camera; chọn sản phẩm/store/tích hợp và dữ liệu cần xử lý.
- [ ] Có contract entitlement đáng tin cậy, sandbox test và các ca mua/restore/hết hạn/lỗi; không dùng cờ VIP phía client làm nguồn sự thật.

### 22. T22 — Quảng cáo nhẹ không chặn lượt xem camera đầu

**Blocked by:** T21. **Đầu ra:** App hiển thị quảng cáo theo chính sách sau khi người dùng đã hoàn tất lượt xem đầu hoặc nhận lỗi nguồn rõ ràng.

**Nghiệm thu:**
- [ ] Không quảng cáo toàn màn chặn mở ảnh đầu, không khiến thao tác đóng quảng cáo thành đánh dấu Quan tâm ngoài ý định.
- [ ] Ad load lỗi không chặn camera; tần suất/session/lifecycle và cấu hình test được kiểm chứng. Ticket chưa gồm bán VIP.

### 23. T23 — Mua/khôi phục VIP để bỏ quảng cáo

**Blocked by:** T22. **Đầu ra:** Mua hoặc restore hợp lệ → entitlement được xác minh → quảng cáo bị tắt nhất quán.

**Nghiệm thu:**
- [ ] Sandbox mua/restore/hết hạn/thu hồi và lỗi mạng theo T21; trạng thái được đối soát từ nguồn đã chốt, không tin giá trị client tự gửi.
- [ ] VIP không làm đổi luồng camera; webhook/event lặp không cấp quyền sai. Kiểm chứng cả hai store khi có tài khoản/môi trường; không tự mua hoặc publish khi chưa được cho phép.

## Đợt E — LIVE có điều kiện

### 24. T24 — Chốt nguồn LIVE khả thi cho Android/iOS

**Cơ sở:** R-11, IMP-01/04 phần stream. **Blocked by:** Không. **Loại:** nghiên cứu quyết định/đặc tả, dự kiến `needs-info`.

**Đầu ra:** Quyết định triển khai một nguồn HTTPS tương thích hoặc hoãn với bằng chứng. Không tái hỏi việc đã chọn Notis cho snapshot.

**Nghiệm thu:**
- [ ] Xác nhận contract nguồn, codec, auth/expiry, quota/bandwidth, đường dữ liệu qua backend theo quy tắc dự án và phép thử Android/iOS.
- [ ] Chốt timeout/retry/fallback snapshot, secret redaction, TLS chuẩn và giới hạn chi phí. Không coi EVUP/WSS hoặc một URL có đuôi m3u8 là bằng chứng nguồn phát được.

### 25. T25 — Phát một nguồn LIVE HTTPS và quay về snapshot khi lỗi

**Blocked by:** T24. **Đầu ra:** Camera có capability được hỗ trợ → phát nguồn đã chọn → lỗi/timeout có lối thoát về snapshot đúng camera.

**Nghiệm thu:**
- [ ] Descriptor/player/đường media theo spec T24; không hiện LIVE cho camera chỉ có snapshot và không lộ credential nguồn.
- [ ] Có test playback thực trên Android/iOS, expiry/mất mạng/đóng/background và TLS lỗi; không loading vô hạn hoặc retry sau khi rời màn. Chỉ hỗ trợ loại nguồn đã duyệt, chưa tự thêm EVUP/YouTube.

## Đối chiếu backlog và quyết định hoãn

| Nguồn | Xử lý trong đề xuất |
|---|---|
| IMP-01 | T02 cho snapshot; T24–T25 cho stream. Không giả định có backup nguồn tự động. |
| IMP-02 | T21–T23; chưa thêm quảng cáo vào A1 chỉ vì backlog ghi P0. |
| IMP-03 | T01–T02 và T09; giữ phân biệt freshness/giờ chụp, không khôi phục text thời gian đã bị loại khỏi sheet. |
| IMP-04 | Guard snapshot hiện có được giữ; T03–T04/T08/T24–T25 kiểm chứng đường chạy mới, không dựng lại toàn bộ TLS layer. |
| IMP-05 | Nhóm Quan tâm theo chuyến đi và label riêng: giữ ở danh sách lựa chọn, chưa đủ xác nhận giá trị để biến thành việc bắt buộc; độc lập với khả năng lưu tuyến T19. |
| IMP-06 | Tìm không dấu cơ bản đã có; alias địa danh và đa tỉnh hoãn, TP.HCM vẫn là phạm vi đầu. |
| IMP-07 | T09, chỉ metadata offline; không mặc định lưu video/ảnh vào đĩa. |
| IMP-08 | T15–T20 bao phủ mưa/nguy cơ theo nguồn đã chốt. Cảnh báo ngập thực chỉ mở ticket riêng khi có dữ liệu xác minh. |
| R-01, R-03–R-05 | A1 đã có luồng tương ứng; T01–T05 bổ sung nhánh lỗi và bằng chứng, không phục hồi ba tab đã bị thay thế. |
| R-02, R-06–R-10 | T10–T14; district filter hiện có không đồng nghĩa đã có map, geocoding hoặc nearby. |
| R-11 | T24–T25, tùy tính khả thi nguồn. |

Không thêm tài khoản/sync đa thiết bị, lịch sử video, PTZ, Redis/microservices, tỉnh mới hoặc reverse-engineering lại app gốc vào đợt A1. Phát hành lên store, tài khoản phát hành và chi phí dịch vụ cần kế hoạch riêng nếu được chọn.

## Quan hệ phụ thuộc và phạm vi duyệt

- A1: T01 + T02 → T03, T04. T05 độc lập. T06 → T07 → T08. Đóng T08 không thay thế T03–T05; trước khi gọi bản dùng thử đạt Android/iOS cần đủ bằng chứng tương ứng và smoke HTTPS.
- Offline: T09 độc lập, không bị chặn giả bởi bản đồ hoặc production.
- Vị trí: T10 → T11 → T12 → T13, T14. T19 dùng bản đồ T11; chọn đầu/cuối theo tọa độ không bắt buộc chờ tìm địa điểm hoặc GPS.
- Thời tiết: T15 → T16 → T17; T13 + T17 → T18; T17 + T19 → T20. Thời tiết khu vực không bị chặn giả bởi việc triển khai bản đồ.
- Doanh thu: T21 → T22 → T23. LIVE: T24 → T25. Hai nhánh này không bị chặn giả bởi thời tiết/bản đồ.

Phạm vi đã duyệt: T01–T08, giữ nguyên độ nhỏ và phụ thuộc; đã xuất blockers trước lên GitHub. Các nhánh T09–T25 chỉ được xuất sau khi người dùng chọn và duyệt riêng; tiếp tục kiểm tra độ nhỏ, quan hệ phụ thuộc, spec và điều kiện tài nguyên trước khi tạo.

## Giới hạn rà soát mã

Đã dùng graph `D-lovi-etown` để tìm symbol và trace preview; coverage báo `metadata_changed`, một số snippet Dart chỉ có chữ ký method. Đã đọc trực tiếp các đoạn source liên quan ở catalog/preview, API repository, API client, sheet/state và API guard để kiểm tra các nhận định chính; không dùng việc graph không có symbol làm bằng chứng tính năng không tồn tại.

T01 dựa trên kiểm tra header trong API client, sau đó frame được nhận và đưa vào preview/cache trước khi widget decode. T02 dựa trên nhánh retry/polling khi chưa có camera/endpoint và UI giữ frame khi refresh lỗi. Đây là các rủi ro tĩnh cần regression test xác nhận, không phải tuyên bố đã tái hiện trên thiết bị. Phần còn lại chủ yếu đối chiếu phạm vi/bằng chứng trong tài liệu, không phải full code audit hoặc thử lại provider hiện tại.
