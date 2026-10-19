# Camera Liquid Glass — vòng thiết kế 1

Ngày: 2026-10-16. Công cụ: Stitch CLI 0.11.1. Đây là mockup tham khảo, chưa phải UI Flutter hoặc shader `liquid_glass_widgets` đã chạy.

Project: `15634181901662145156` — TTGT TP.HCM - Liquid Glass Mobile A1.

## Prototype tương tác mới nhất

[Mở file HTML tương tác](camera-interaction-prototype.html) · [Hướng dẫn và bằng chứng](camera-interaction-prototype.md) · [Các artboard/links Stitch](camera-prototype-artboards.md).

Có luồng list → sheet → viewer, zoom/pan, bố cục ngang, light/dark, loading/lỗi ảnh và Quan tâm rỗng. Sheet giữ yêu cầu bỏ toolbar/text thời gian. HTML mới có tương tác; các artboard Stitch là trạng thái tĩnh. Dữ liệu mẫu, không API hoặc product Flutter code.

## Hướng mới nhất — Camera + snapshot bottom sheet

Người dùng yêu cầu bỏ page riêng cho Quan tâm và chi tiết chỉ xem snapshot, kèm ảnh reference `camera-bottom-sheet.jpg`. Thay các bản page bên dưới bằng một màn Camera: Quan tâm là section thu gọn/bộ lọc “Chỉ quan tâm”, card mở modal bottom sheet trên chính grid. Không còn hai-tab Camera/Quan tâm trong A1; roadmap khác giữ nguyên.

- [Màn Camera với Quan tâm inline](https://stitch.google.com/projects/15634181901662145156?node-id=17833083762628583982) — [PNG](camera-inline-favorites-review.png), [HTML](camera-inline-favorites-review.html).
- [Snapshot bottom sheet](https://stitch.google.com/projects/15634181901662145156?node-id=8405138958362570852) — [PNG](camera-sheet-tap-review.png), [HTML](camera-sheet-open-review.html).

Hai screen đã được xác minh bằng `stitch get screen` và kiểm tra screenshot render. Manifest: [camera-sheet-review-manifest.json](camera-sheet-review-manifest.json).

Sheet có handle, Close X, tên đầy đủ, saved star và snapshot toàn tỷ lệ. Đã bỏ hai nút Làm mới/Toàn màn hình và toàn bộ text thời gian. Chạm ảnh mở viewer overlay; hỗ trợ xoay ngang, pinch zoom, pan khi zoom và double-tap fit/zoom theo đặc tả Flutter. Chiều cao co theo nội dung; không related list, không pencil sửa tên, không khoảng trắng lớn. Close/Back/swipe/scrim giữ context list. Đây là mockup tĩnh, gesture/orientation/lifecycle chưa được nghiệm thu. Timestamp in sẵn trong JPEG nguồn giữ nguyên.

**Provenance và sửa lỗi:** Stitch draft dùng ảnh generated có cả UI screenshot và tự thêm số 718/đánh giá giao thông/tốc độ. Review HTML thay toàn bộ img bằng JPEG local đã kiểm tra; sheet ghép lên cùng HTML main để background nhất quán, loại timestamp overlay giả, claim giao thông và code tự refresh/reopen. Raw draft giữ nguyên để đối chiếu. Saved star dùng SVG filled. Script tái dựng: `scripts/ui/build-camera-sheet-review.ps1` (chạy từ workspace); không sửa `mobile/lib/` hoặc gọi upstream mới.

Các tên/phường/metadata của grid vẫn là dữ liệu minh họa có nhãn; không chứng nhận map ảnh với catalog thật. Rendering HTML/backdrop blur không chứng minh shader/refraction package Flutter, detents/drag/focus/polling. Các page standalone dưới đây là lịch sử bị feedback mới thay thế, không là navigation cần triển khai.

## Lịch sử — Chi tiết và Quan tâm dạng page

Người dùng đã chấp thuận hướng v3 và đồng ý tiếp tục. Đã tạo ba artboard, gắn lại JPEG camera đã xác minh trong HTML và import bản review cuối lên Stitch:

| Màn | Stitch | Ảnh | HTML |
|---|---|---|---|
| Chi tiết snapshot | [Mở Chi tiết](https://stitch.google.com/projects/15634181901662145156?node-id=12538486518867795532) | [PNG](camera-detail-final.png) | [HTML](camera-detail-review.html) |
| Quan tâm có dữ liệu | [Mở Quan tâm](https://stitch.google.com/projects/15634181901662145156?node-id=6984728961356815463) | [PNG](favorites-populated-final.png) | [HTML](favorites-populated-review.html) |
| Quan tâm rỗng | [Mở trạng thái rỗng](https://stitch.google.com/projects/15634181901662145156?node-id=13088157116766237497) | [PNG](favorites-empty-viewport.png) | [HTML](favorites-empty-review.html) |

**Nội dung thiết kế:** Chi tiết có ảnh đầy đủ tỷ lệ, Back, saved star, Làm mới, Mở rộng, thời điểm backend nhận ảnh tách khỏi giờ chụp nguồn chưa biết; cảnh báo ảnh cũ giữ ảnh và gợi ý thử lại. Quan tâm có search, Card/Grid/List, ba camera mẫu có ảnh và một trạng thái camera không còn trong catalog nhưng vẫn cho bỏ Quan tâm. Màn rỗng có ngôi sao, hướng dẫn và CTA Tìm camera; không yêu cầu đăng nhập hoặc GPS.

**Quan sát output:** Stitch lần này dùng placeholders thay ảnh search sai; đã thay tất cả img bằng ba JPEG local đã kiểm tra, retained raw generated files. Đã bỏ nhãn kỹ thuật 16:9, câu tự suy cơ chế máy chủ đồng bộ và khẳng định “Lưu trữ cục bộ an toàn”; sửa nhãn ngừng hoạt động thành trạng thái không còn khả dụng/danh mục. UI không chứng minh các địa chỉ hành chính mẫu hiện hành hoặc quan hệ related thật. Khi code, label nullable/related phải lấy backend.

**Giới hạn:** đây là thiết kế HTML/screenshot; actions, search/modes/favorites persistence, image refresh, 404 và cảnh báo stale chưa chạy trên Flutter. Dark mode, List gọn/grid mật độ, expanded image và state lỗi/loading đầy đủ chưa có artboard riêng. Không coi các bản này là phê duyệt triển khai Flutter hoặc nghiệm thu shader `liquid_glass_widgets`.

Prompt và provenance: [detail-favorites-prompt.txt](detail-favorites-prompt.txt), `detail-favorites-generation.json`, `*-generated.*`, `*-final-upload.json`, `*-final-screen.json` và [manifest](detail-favorites-manifest.json). Một lần upload Quan tâm populated trả AUTH_FAILED 403, lần thử lại và các bản cuối thành công; không đổi credentials/quyền truy cập. CLI Windows vẫn in assertion lúc thoát; trạng thái được xác minh bằng JSON success và get-screen phía server.

## Bản review hiện tại — v3 theo ba ảnh mẫu

**Phản hồi người dùng:** “ok” sau khi xem bàn giao Grid/Card/Dropdown v3. Ghi nhận chấp thuận hướng hình ảnh để tiếp tục thiết kế các màn còn lại; không đồng nghĩa đã nghiệm thu interaction, shader, backend hoặc phê duyệt triển khai Flutter.

Bước thiết kế kế tiếp: Chi tiết snapshot và Quan tâm cùng visual system; bổ sung List gọn/grid mật độ và dark/error/empty states. Giữ dropdown địa điểm, ảnh trong list và infinite loading đã chốt.

Người dùng đổi yêu cầu: dropdown địa điểm, mode Card/Grid/List, snapshot ngay trong list và infinite loading; yêu cầu Liquid Glass rõ hơn. Thay thế hướng text-only của v1/v2. References và upload metadata tại [references](references/README.md).

| Bản review | Stitch | PNG | HTML |
|---|---|---|---|
| Grid 2 cột | [Mở Grid](https://stitch.google.com/projects/15634181901662145156?node-id=8278298733313211302) | [Ảnh Grid](camera-v3-grid-review.png) | [HTML Grid](camera-v3-grid-review.html) |
| Card ảnh lớn | [Mở Card](https://stitch.google.com/projects/15634181901662145156?node-id=5363005408800856859) | [Ảnh Card](camera-v3-card-review.png) | [HTML Card](camera-v3-card-review.html) |
| Dropdown đang mở | [Mở Dropdown](https://stitch.google.com/projects/15634181901662145156?node-id=18241151456201549198) | [Ảnh Dropdown](camera-v3-dropdown-review.png) | [HTML Dropdown](camera-v3-dropdown-review.html) |

**Đã kiểm tra:** mở cả ba screenshot đã import; HTML dùng 7/3/6 img với JPEG camera riêng đã embed, không còn ảnh generated/person/UI screenshot làm thumbnail. Có selector khu vực, Card/Grid/List, hai tab Camera/Quan tâm, loading footer “Đang tải thêm…”, không nút tải thêm trong happy path. Bản dropdown cho thấy ảnh camera mờ truyền qua popover; saved stars được thay SVG filled để tránh font icon không hiện fill. Chưa kiểm chứng shader/refraction native hoặc interaction của các mode.

**Provenance:** Stitch tạo 3 artboard từ reference, sau một vòng correction vẫn tự thêm ảnh người/tượng hoặc screenshot UI làm thumbnail. Các bản generated `camera-v3-*.png` và `*-corrected.png` là draft có lỗi, không phải bản review được chọn. Đã sửa asset wiring trong HTML mockup, embed đúng ba JPEG từ Notis đã mở xem, đổi saved stars sang SVG và tăng vùng chạm; sau đó upload HTML lại bằng CLI. Snapshot asset bytes/hash/source trong [assets/snapshot-assets.json](assets/snapshot-assets.json). Đây chỉ là ảnh minh họa bố cục, ảnh có thể lặp; tên/phường của mockup chưa map với ảnh và không phải catalog production. Không sửa các ảnh gốc hoặc triển khai code trong `mobile/lib/`.

**Giới hạn còn lại:** các mode/infinite loading thể hiện thiết kế, chưa là pagination/runtime thật; List gọn và grid 3 cột mới có affordance, chưa có artboard riêng. Card xuất thành capture dài; imported HTML canvas có khoảng nền desktop quanh viewport mobile. Khi code phải thống nhất chiều cao bar/font/wrap giữa các bản, dùng label địa điểm backend thực, bảo đảm footer không bị dock che và chọn glyph filled/outline ổn định. Glass trong HTML dùng backdrop blur/translucency; không chứng nhận tương đương shader `liquid_glass_widgets`.

Prompt v3: [camera-v3-prompt.txt](camera-v3-prompt.txt); generation/correction raw JSON và upload/get-screen payload lưu cùng thư mục. Không lấy prose design system tự sinh (còn copy nhầm số 718, offline, pinned routes) làm nguồn yêu cầu; brief/spec hiện hành là cơ sở.

## Lịch sử bản v2

- Screen ID xác minh bằng `stitch get screen`: `f4b077a13f3a42db99b0df38fc835b88`.
- [Mở bản v2 trên Stitch](https://stitch.google.com/projects/15634181901662145156?node-id=f4b077a13f3a42db99b0df38fc835b88).
- [Ảnh v2](camera-light-v2.png), [HTML v2](camera-light-v2.html), [screen payload](camera-light-v2-screen.json), [kết quả edit](camera-light-refinement.json).
- CLI edit trả `id` màn nguồn nhưng canvasUrl trỏ màn mới; dùng ID màn mới ở trên sau khi get xác minh, không ghi đè ID cũ.

**Quan sát screenshot/HTML v2:** 6 thẻ và nhãn “Đã tải 6 camera” khớp; tên/địa chỉ wrap dễ đọc; chip/tim/clear có vùng chạm 48px theo HTML; đúng hai tab, có nhãn dữ liệu mẫu, không có thumbnail hoặc LIVE. Ảnh xuất 780×2352 là capture dài của nội dung, chưa là kiểm chứng viewport 390×844 có tương tác.

**Còn cần review:** mức glass nhìn khá nhẹ trên nền sáng, refraction/motion chưa được chứng minh; tab Quan tâm wrap hai dòng; screenshot vẫn thể hiện tim dạng outline dù HTML có font variation FILL cho hai camera đã lưu. Khi triển khai cần bảo đảm icon selected filled thật. Top filter vẫn có aria-label “Bộ lọc nâng cao” dù brief chỉ cho lọc district; sửa nhãn và scope trong bản Flutter. Chưa coi đây là thiết kế cuối đã được người dùng duyệt.

## Bản đầu đã tạo

- Screen ID: `cec97e472caa45eebb6d809962eb2c97`.
- [Mở trên Stitch](https://stitch.google.com/projects/15634181901662145156?node-id=cec97e472caa45eebb6d809962eb2c97).
- [Ảnh gốc 780×2612](camera-light-full.png); [HTML tham khảo](camera-light.html).
- [Prompt](camera-light-prompt.txt), [generation output](camera-light-generation.json), [manifest](camera-light-manifest.json).

**Quan sát screenshot + HTML đã tải:** đúng hai tab Camera/Quan tâm, tiếng Việt, teal, search/filter, thẻ metadata không có thumbnail, có nhãn dữ liệu mẫu, không LIVE hoặc quảng cáo. Có CSS blur/translucency cho chrome; chưa chứng minh hiệu ứng refraction/motion native.

**Điểm cần sửa đã gửi Stitch:** tên/address bị truncate nhiều; danh sách 9 thẻ nhưng nhãn đã tải 12; chip cao 36px và clear button 40px chưa đạt mục tiêu 48px; trạng thái favorite dùng outline ở cả hai trạng thái; screenshot dài cần kiểm chứng bố cục viewport/safe area. Prompt vòng sửa ở [camera-light-refinement-prompt.txt](camera-light-refinement-prompt.txt).

**Giới hạn design system tự sinh:** phần prose trong output ban đầu tự nhắc bốn tab, maps, LIVE và cảnh báo ngập dù màn Camera thực tế không có. Đây là nội dung ngoài brief, không phải yêu cầu sản phẩm. Không dùng raw generated designMd để thay `mobile/DESIGN.md` hoặc mở rộng scope. Đã yêu cầu sửa prose cùng mockup.

## Hướng component để review

- Teal accent, nền trung tính sáng, thẻ metadata opaque, typography Be Vietnam Pro là đề xuất từ bản tạo; chưa chốt font/dependency Flutter.
- Floating bottom capsule → `GlassTabBar.bottom`; header → `GlassAppBar`; search/filter → `GlassSearchBar`, `GlassChip`; tim/action → `GlassIconButton`.
- Màu/token cuối cùng phải hòa giải với starter sau khi người dùng review.
- Chưa thiết kế Chi tiết/Quan tâm/dark/state variants; thực hiện sau khi chọn phong cách màn Camera.
- Chưa build/chạy Flutter, kiểm chứng FPS/accessibility hoặc nối backend.

