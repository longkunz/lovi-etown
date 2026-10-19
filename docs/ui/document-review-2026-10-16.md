# Review tài liệu trước thiết kế Liquid Glass

Ngày: 2026-10-16. Phạm vi: tài liệu dự án trong `docs/`, tài liệu starter `mobile/`, README và verification của `backend/`, hướng dẫn root; tham khảo thêm README/agents của ePlus và evidence index. Danh sách 40 file Markdown thuộc ba nhóm chính được lưu tại `document-inventory-2026-10-16.json` (hash tại thời điểm review, trước cập nhật). Không audit lại mã dịch ngược, dependencies/vendor, toàn bộ raw evidence hay tài liệu bên ngoài workspace được dẫn link.

## 1. Kết luận cho UI

**Yêu cầu người dùng:** Flutter + BLoC + FlutterInit trong `mobile/`; thiết kế bằng Stitch trước khi code; style **Liquid Glass dùng `liquid_glass_widgets`**. Đây là quyết định sản phẩm, không phải quan sát reverse. Package là lựa chọn triển khai đã chốt; màu nhấn, bố cục và cường độ hiệu ứng cụ thể vẫn là đề xuất để review trên mockup.

**Tổng hợp tài liệu:** A1 là danh sách/tìm kiếm → chọn camera → snapshot → thêm/bỏ Quan tâm local → mở lại. Android + iOS, TP.HCM trước, backend riêng dùng Notis đã chọn. A1 không cần GPS, map hay Vietmap để xem camera. Giữ cả roadmap bản đồ/nearby/Vietmap, LIVE theo nguồn, cảnh báo khu vực lưu/vị trí hiện tại/tuyến thường đi, quảng cáo nhẹ và VIP. Không đưa các tính năng chưa có contract vào tab A1.

Nguồn quyết định: `superpowers/brainstorming-status.md`, `superpowers/specs/2026-10-14-camera-backend-design.md` §§1/1.1, `superpowers/specs/2026-10-15-camera-mobile-a1-design.md` §§1–6, `backend-reverse-traceability.md`. Các dự thảo reverse/rebuild đời đầu có phạm vi ba tab Quan tâm/Bản đồ/Xung quanh là tham khảo hành vi app gốc, không thay thế phạm vi A1 đã điều chỉnh.

## 2. Điểm lệch và cách áp dụng

| Điểm trong tài liệu | Loại / đối chiếu | Kết luận áp dụng |
|---|---|---|
| Mobile spec đề xuất Material 3, starter ghi Cupertino | Quan sát tài liệu `mobile/AGENTS.md`, `mobile/DESIGN.md`; yêu cầu người dùng mới nhất | Liquid Glass là hướng chính; Cupertino của starter là nền để tích hợp, không ép đổi sang giao diện Material |
| Brief cũ chỉ nói glass nhẹ, chưa chọn package | Quan sát `ui/stitch-brief.md` trước cập nhật | Ghi rõ package và mapping component; glass nổi bật ở navigation/controls, nội dung dễ đọc |
| Spec/status/investigation còn ghi chưa generate mobile | Quan sát tài liệu so với `mobile/README.md`, `pubspec.yaml` và xác nhận người dùng | Starter đã hiện diện; chưa đồng nghĩa camera UI/API integration hoặc build đã hoàn tất |
| Header backend spec/plan còn ghi chờ thực thi | Quan sát báo cáo `backend/docs/verification.md` và checkbox plan | Backend đã có báo cáo 49 tests/smoke ngày 14/10; đây là bằng chứng lịch sử, không khẳng định lượt này chạy lại hoặc production-ready |
| BLoC so với đề xuất Riverpod/ViewModel trước; SQLite so với Shared Preferences | Quyết định mới hơn trong Mobile A1 và starter | Giữ BLoC/Cubit, Shared Preferences cho favorites A1; không thêm state library hoặc DB mobile vì tài liệu cũ |
| Backend spec có thumbnailEndpoint; Mobile A1 chọn thẻ thông tin | Khác năng lực API và chính sách UI, không phải lỗi contract | Danh sách/Quan tâm A1 dùng metadata, không poll ảnh toàn danh mục; snapshot dành chi tiết đang xem |
| Related cùng district dễ bị gọi “gần đây/gần bạn” | Mobile A1 §4 và backend spec §3 | Nhãn “Camera cùng khu vực” khi có dữ liệu district, không bịa khoảng cách/gần nhất; thiếu district thì ẩn section |
| `SETUP.md` có quyền vị trí/background location chung | Tài liệu scaffold, khác nhu cầu A1 | A1 không tạo onboarding xin vị trí; chỉ thiết kế permission khi đến tính năng thật cần nó |
| Starter gọi dotenv là nơi chứa secrets | Tài liệu scaffold; Mobile A1 §6 đã nêu giới hạn | Chỉ cấu hình môi trường; không coi key nhúng client là bí mật. Không đưa key/backend admin vào prompt/UI |
| Kế hoạch backend ghi CommonJS trong constraints, README ghi ESM | Mâu thuẫn tài liệu triển khai | Không ảnh hưởng mockup; khi code tích hợp phải kiểm tra config thực, chưa kết luận từ hai mô tả |
| OpenAPI đề xuất `/openapi.json`, verification ghi `/docs-json` | Spec vs báo cáo triển khai | UI lấy contract v1 trong Mobile A1; kiểm tra OpenAPI thực khi tích hợp, không sửa backend trong lượt review |

Không viết lại các nhật ký reverse cũ để xóa trạng thái lịch sử. Các ghi chú cập nhật mới phải được ưu tiên, nhưng không nâng toàn bộ mục chưa kiểm chứng thành hoàn tất.

## 3. Bằng chứng reverse ảnh hưởng thiết kế

Đây là **tổng hợp báo cáo đã lưu**, không phải quan sát runtime mới:

- `camera-runtime-pass3.md`, `camera-runtime-pass4.md`: giữ ảnh cuối khi lỗi có thể khiến người xem hiểu nhầm. UI mới cần nhãn ảnh cũ/lỗi và hành động thử lại.
- `camera-contract-pass6.md`, `camera-api-debug-pass7.md`, `api-catalog.md`: số 89/90 là các mẫu; không dùng làm hằng số hoặc cam kết toàn bộ camera trong bán kính. UI ghi “Đã tải N camera”, không đồng nhất tổng local với coverage nguồn.
- `data-model.md`, `catalog-cache-favorites.md`, `backend-reverse-traceability.md`: ID domain backend dùng cho favorites; không lưu URL ảnh làm khóa, không gộp camera chỉ vì trùng tên.
- `android13-playback.md`, `player-runtime.md`, `recovery-and-backup.md`: app tham khảo có nhiều media path; không vì đã thấy WSS/HLS/YouTube ở app gốc mà thêm LIVE vào A1.
- `research-eplus-camera.md`: 123 ID ứng viên chưa phải camera hoạt động/được import; không dùng con số 797/900/726 để quảng bá độ phủ UI mới. Không tự đổi Notis sang proxy nguồn ePlus.
- `camera-spec.md`, `rebuild-spec.md`: map/nearby/geocoding là flow tham khảo; lỗi tìm địa điểm và lỗi reverse geocoding khác nhau. Chúng giữ trong roadmap sau A1, không biến thành dependency xem snapshot.

Metadata ảnh phải tách rõ: `X-Image-Fetched-At` là lúc backend nhận ảnh, không phải giờ camera chụp. `capturedAt=null` phải giữ nghĩa chưa biết. 304 không chứng minh ảnh nguồn mới. Thiếu timestamp không tự điền thời gian hiện tại. Không gán online hoặc mức ùn tắc từ việc có record/ảnh.

## 4. Đối chiếu package đã chọn

**Quan sát tài liệu upstream ngày review:** pub.dev và API metadata trả bản `liquid_glass_widgets` **1.13.0**, Flutter **≥3.41.0**, Dart constraint **≥3.5.0 <4.0.0**. Đây là phiên bản tham chiếu thiết kế; chưa thêm dependency hoặc lockfile và chưa kiểm chứng trên SDK local. `Get-Command flutter,dart` không trả executable trong PATH shell hiện tại; không kết luận máy chưa cài SDK.

Nguồn: [README package](https://pub.dev/packages/liquid_glass_widgets), [metadata pub.dev](https://pub.dev/api/packages/liquid_glass_widgets), [changelog](https://pub.dev/packages/liquid_glass_widgets/changelog).

**Theo hướng dẫn tác giả, chưa là benchmark của dự án:** dùng glass chủ yếu cho navigation và controls; nội dung giữ nền opaque. Dùng `GlassScaffold` cho màn có bars; tránh bọc controls glass trong `GlassCard`/`GlassContainer`. Premium có giới hạn trong scroll views; fallback và Reduce Motion/Increase Contrast cần nghiệm thu thực tế, không mặc định package tự đảm bảo mọi tiêu chí accessibility.

| Phần thiết kế | Component tham chiếu |
|---|---|
| Shell, background, z-order, safe area | `GlassScaffold` |
| Header, back, actions | `GlassAppBar`, `GlassIconButton` |
| Hai tab Camera / Quan tâm | `GlassTabBar.bottom` |
| Tìm tên/địa chỉ | `GlassSearchBar` |
| Lọc khu vực | `GlassChip`, `GlassModalSheet` hoặc `GlassMenu` |
| Tim, làm mới, mở rộng ảnh | `GlassIconButton`, `GlassButton` |
| Danh sách, metadata, ảnh snapshot | Widgets nội dung nền đặc; không phủ glass toàn ảnh |

Khi code: `LiquidGlassWidgets.initialize()` và `LiquidGlassWidgets.wrap()` theo version được pin; nếu app root dùng MaterialApp thì dùng brightness resolver theo README. Không suy từ preset Cupertino rằng root thực sự là CupertinoApp. Kiểm tra code/config bằng graph + coverage khi triển khai. Giữ tokens hiện có; đưa glass vào lớp UI dùng chung để tránh mỗi feature tự cấu hình shader. Không tạo controller điều hướng cạnh tranh với go_router; mapping `GlassNavigationShell` chỉ cân nhắc sau kiểm tra tương thích, không mặc định thêm ngay.

## 5. Tiêu chí cho vòng thiết kế

1. Màn Camera có search, filter nếu có district, thẻ tên/địa chỉ nullable, tim, trạng thái tải/rỗng/lỗi và tải thêm.
2. Chi tiết có ảnh đúng tỷ lệ, tim, làm mới, mở rộng, thời điểm backend nhận ảnh/unknown; lỗi refresh giữ ảnh và cảnh báo; chưa hỗ trợ có thông báo rõ.
3. Quan tâm có dữ liệu, rỗng, camera không còn khả dụng và lỗi lưu/phục hồi local. Không thêm đăng nhập/sync account.
4. Light/dark dùng cùng design system; glass có thể nhìn thấy ở bars/controls nhưng chữ vẫn rõ, có bản giảm hiệu ứng/opaque khi cần.
5. Vùng chạm mục tiêu ít nhất 48 logical px, nhãn screen reader cho tim/back/refresh/fullscreen; font lớn không che CTA; motion không cản thao tác.
6. Dữ liệu mock ghi “Dữ liệu mẫu”; không có fake LIVE/online, cảnh báo ngập hoặc quảng cáo/quyền vị trí chặn flow.
7. Stitch chỉ xác minh bố cục/hình thức. Refraction, chuyển động, shader, FPS và accessibility thực tế cần prototype Flutter trên Android/iOS sau khi chọn thiết kế.

## 6. Trạng thái cuối review

**Quan sát CLI:** `stitch status --json` trả authenticated/Valid và Canvas credential OAuth present; không lưu email/token trong tài liệu. Chưa gọi generate hoặc tạo external project trong lượt review. Brief và Mobile A1 được cập nhật theo yêu cầu mới; chưa sửa product code, cài dependency Flutter hoặc chạy build/tests backend/mobile.

**Bước tiếp:** dùng brief đã hợp nhất để tạo màn Camera Liquid Glass trên Stitch, review phong cách rồi áp dụng cho Chi tiết/Quan tâm và state variants. Trước triển khai Flutter cần chốt mockup, ánh xạ tokens/components và kiểm chứng SDK/package renderer thực.
