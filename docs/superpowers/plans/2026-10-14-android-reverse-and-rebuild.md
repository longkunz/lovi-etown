# Kế hoạch reverse Android và chuẩn bị ứng dụng mới

> **For agentic workers:** Dùng `superpowers:executing-plans` khi thực hiện lần lượt kế hoạch trong phiên hiện tại. Các checkbox theo dõi công việc điều tra; đây chưa phải kế hoạch viết mã sản phẩm.

**Goal:** Xác minh tech stack, flow và API của `com.genius.cameragiaothong`, sau đó tạo đặc tả khả thi cho app mới có cải tiến rõ ràng.

**Architecture:** Phân tích artifact bằng REA/JADX, lần theo mã bằng codebase memory và kiểm chứng các câu hỏi còn mở trên Android Emulator bằng ADB/Frida. Mọi phát hiện gắn với artifact và bằng chứng; đặc tả sản phẩm được tổng hợp riêng từ hành vi đã xác minh.

**Tech Stack:** Công cụ điều tra theo `AGENTS.md`. Stack của app gốc chưa được xác minh; stack của app mới được quyết định ở giai đoạn 6.

**Spec:** [AGENTS.md](../../../AGENTS.md), cùng mục tiêu người dùng đã cung cấp. Đã bắt đầu thực hiện điều tra; tiến độ và giới hạn hiện tại ở `docs/investigation.md`.

## Ràng buộc chung

- Giữ nguyên APK và dữ liệu trích xuất hiện có; đặt đầu ra mới trong `docs/`, `evidence/`, `scripts/` hoặc `analysis/`.
- Xác minh phiên bản và hash trước khi kết hợp bằng chứng từ các nguồn.
- Dùng skill REA cho artifact/runtime; dùng skill codebase-memory cho khám phá cấu trúc mã. Index trước khi truy vấn và kiểm tra coverage của mọi file làm cơ sở kết luận.
- Ghi rõ quan sát tĩnh, quan sát runtime, suy luận và phần chưa xác minh. Một URL trong mã chưa chứng minh request đã xảy ra.
- Báo cáo và mẫu dữ liệu được chia sẻ phải che thông tin xác thực và dữ liệu cá nhân.
- Tái sử dụng công cụ/session có sẵn; chẩn đoán lỗi cụ thể trước khi sửa môi trường.
- Không mặc định API, tài nguyên hoặc dữ liệu của app gốc có thể dùng cho sản phẩm mới.

## Những điểm cần kiểm chứng kỹ

| Điểm dễ sai | Cách kiểm chứng | Giai đoạn |
|---|---|---|
| Base và split APK khác phiên bản; bản trích xuất cũ | Đối chiếu metadata, hash và nguồn trích xuất | 1 |
| SDK đóng gói bị hiểu thành stack nghiệp vụ | Theo dấu caller và entry point thực sự | 2–3 |
| URL tĩnh bị hiểu thành API đang dùng; thiếu URL ghép động | Theo dõi chỗ tạo request và quan sát runtime | 4–5 |
| Mất mạng, từ chối quyền, response rỗng bị bỏ sót | Tái hiện và ghi state/UI cùng request liên quan | 5 |
| Đề xuất cải tiến phụ thuộc nguồn dữ liệu chưa khả thi | Ghi phương án dữ liệu và phép thử khả thi | 6 |

## Đầu vào đã thấy trong workspace

- `com.genius.cameragiaothong/base.apk`
- `com.genius.cameragiaothong/split_config.hdpi.apk`
- `com.genius.cameragiaothong/split_config.vi.apk`
- `com.genius.cameragiaothong/split_config.x86_64.apk`
- `extracted/base/` và các thư mục split tương ứng.
- `apktool_out/` với manifest, tài nguyên và smali.

Đây là kiểm kê đường dẫn; chưa xác nhận nội dung, phiên bản, tính đồng bộ hoặc công nghệ bên trong.

## Giai đoạn 1: Chốt artifact và thiết lập hồ sơ điều tra

**Đầu ra:** `docs/investigation.md`, `evidence/artifact-inventory.json`; `analysis/jadx/` nếu cần xuất mã mới.

- [x] Tính SHA-256 cho bốn APK bằng `Get-FileHash -Algorithm SHA256`; lưu đường dẫn, kích thước và hash trong inventory.
- [x] Đọc metadata package/version/SDK/ABI và split bằng công cụ APK hiện có; xác nhận các split thuộc cùng bộ với base.
- [x] Kiểm tra nguồn và mức đầy đủ của `extracted/`, `apktool_out/` và session REA/JADX hiện có. Nếu không xác minh được nguồn, ghi nhận và tạo bản phân tích mới từ APK đã hash ở đường dẫn riêng.
- [x] Tạo hồ sơ điều tra gồm artifact, câu hỏi, bảng bằng chứng và trạng thái `chưa làm / đang làm / hoàn tất / còn thiếu bằng chứng`.
- [x] Xác định mã nguồn dịch ngược có thể index; xuất bằng JADX vào `analysis/jadx/` nếu cần. Dùng codebase-memory để index phạm vi mã phân tích, ghi root và phần không được hỗ trợ.

**Hoàn tất khi:** Có một bộ artifact xác định; từng nguồn phân tích có provenance hoặc giới hạn rõ ràng; có phạm vi graph sẵn sàng cho giai đoạn tiếp theo. Nếu graph không bao phủ đủ, ghi fallback đọc mã trực tiếp và giới hạn, không kết luận dựa riêng vào graph.

## Giai đoạn 2: Tech stack và bản đồ thành phần

**Phụ thuộc:** Giai đoạn 1.

**Đầu ra:** `docs/tech-stack.md`.

- [x] Dùng REA Android package inspection để lấy tổng quan manifest, thành phần và package; tái sử dụng kết quả tương ứng artifact.
- [x] Xác định framework UI/runtime, ngôn ngữ có bằng chứng, thành phần native và SDK đóng gói. Phiên bản thư viện chỉ ghi khi có metadata hoặc dấu hiệu đủ mạnh.
- [x] Lập bản đồ Application, launcher Activity, service, receiver, provider, deep link và quyền liên quan; ghi entry point cùng vai trò đã xác minh.
- [ ] Lần theo tầng network, lưu trữ, định vị, bản đồ, media, quảng cáo/analytics nếu hiện diện; phân biệt mã nghiệp vụ với SDK bên thứ ba.
- [x] Với mỗi công nghệ, ghi `thành phần | vai trò | bằng chứng | được gọi hay chỉ đóng gói | độ chắc chắn`.

**Hoàn tất khi:** Giải thích được app khởi động bằng gì, UI chính nằm ở đâu, dữ liệu đi qua những tầng nào; mọi phần chưa xác định được ghi riêng.

## Giai đoạn 3: Danh sách tính năng và flow

**Phụ thuộc:** Giai đoạn 2; có thể cập nhật sau giai đoạn 5.

**Đầu ra:** `docs/feature-matrix.md`, `docs/flows.md`.

- [x] Lập danh sách màn hình/tính năng từ entry point, navigation và tài nguyên; gán ID `F-001`, `F-002`, … Các mục mới chỉ suy ra từ mã phải giữ nhãn suy luận.
- [x] Ưu tiên flow khởi động, flow sử dụng chính, flow phụ; ưu tiên phần ảnh hưởng đến dữ liệu cốt lõi trước SDK quảng cáo/analytics.
- [ ] Với từng tính năng, trace `thao tác → handler → logic/state → API hoặc dữ liệu local → UI`; ghi class/method và bằng chứng cho từng đoạn.
- [x] Ghi đầu vào, đầu ra, điều kiện quyền/đăng nhập nếu có, cache, tác vụ nền và nhánh lỗi tìm thấy.
- [x] Vẽ Mermaid cho các flow chính; đánh dấu các đoạn cần runtime để xác nhận, không lấp khoảng trống bằng giả định.

**Hoàn tất khi:** Mỗi tính năng có entry point, kết quả và trạng thái bằng chứng; các flow chính có trace hoặc câu hỏi runtime cụ thể cho đoạn chưa rõ.

## Giai đoạn 4: API catalog và mô hình dữ liệu

**Phụ thuộc:** Giai đoạn 2–3; xác nhận runtime ở giai đoạn 5.

**Đầu ra:** `docs/api-catalog.md`, `docs/data-model.md`.

- [ ] Tìm khai báo client/interface, base URL, interceptor, serializer và request builder. Dùng `rg` cho literal và graph/JADX cho caller.
- [x] Theo dấu URL ghép động, remote config, WebView, endpoint trả về từ server, socket hoặc media URL nếu có dấu hiệu; ghi giới hạn khi không thể xác định tĩnh.
- [x] Gán ID `API-001`, …; ghi host, method, path, query/body, header/auth, response, caller và ID tính năng. Trường chưa rõ ghi `chưa xác minh`.
- [x] Phân loại nghiệp vụ, dữ liệu/media, analytics, quảng cáo và dịch vụ bên thứ ba; liên kết endpoint tương đương để tránh đếm trùng.
- [x] Trích mô hình dữ liệu tối thiểu từ DTO/parser/storage: field, kiểu, nullable/default nếu có bằng chứng, quan hệ và nguồn dữ liệu.
- [x] Tạo danh sách câu hỏi runtime về auth, tham số thực tế, refresh/cache, lỗi và request chỉ được tạo trong điều kiện đặc biệt.

**Hoàn tất khi:** Mỗi endpoint có nguồn bằng chứng và mục đích hoặc câu hỏi còn mở; flow chính liên kết tới API/dữ liệu local tương ứng. Không gọi catalog là đầy đủ tuyệt đối khi còn phạm vi chưa khảo sát.

## Giai đoạn 5: Đối chiếu trên emulator

**Phụ thuộc:** Giai đoạn 1 và danh sách câu hỏi từ 3–4.

**Đầu ra:** `docs/runtime-validation.md`, `evidence/runtime/`; script trong `scripts/frida/` nếu cần.

- [x] Dùng `adb devices -l` và thông tin emulator để xác định thiết bị, Android version và ABI. Kiểm tra app đã cài; chỉ dùng `adb install-multiple` với bộ APK đã xác nhận và thiết bị tương thích khi cần.
- [x] Tạo ma trận ca chạy có ID tính năng, trạng thái ban đầu, bước thao tác, kết quả cần quan sát và bằng chứng sẽ thu.
- [x] Chạy baseline: mở app, navigation và các flow chính đã tìm thấy; thu screenshot/log và request tương ứng bằng khả năng sẵn có.
- [x] Khi cần, viết hook Frida nhỏ nhắm vào method tạo request hoặc xử lý dữ liệu đã xác định. Ghi method được hook, điều kiện hook và ảnh hưởng có thể gây ra; so sánh với baseline.
- [ ] Kiểm tra mất/kết nối lại mạng, từ chối quyền, dữ liệu rỗng hoặc endpoint lỗi khi có cách tái hiện phù hợp. Phân biệt lỗi thật quan sát được với response mô phỏng.
- [x] Đối chiếu từng kết quả với static trace; cập nhật API/flow và giải thích chỗ khác biệt. Ghi blocker cụ thể nếu emulator, đăng nhập, backend hoặc instrumentation không cho kiểm chứng.

**Hoàn tất khi:** Mỗi flow chính đã được đối chiếu runtime hoặc có blocker và phạm vi chưa xác minh rõ ràng. Mỗi ca chạy có bước tái hiện và tham chiếu bằng chứng; không dùng việc thiếu traffic capture để kết luận không có API.

## Giai đoạn 6: Đặc tả app mới và khác biệt sản phẩm

**Phụ thuộc:** Tổng hợp giai đoạn 2–5, bao gồm giới hạn chưa giải quyết.

**Đầu ra:** `docs/rebuild-spec.md`, `docs/improvement-backlog.md`.

- [x] Chuyển feature matrix thành danh sách năng lực cần giữ; phân biệt hành vi quan sát được với yêu cầu mới.
- [x] Tổng hợp vấn đề có bằng chứng và cơ hội cải tiến. Các hướng như tốc độ, khả năng tìm kiếm, độ mới dữ liệu, UX, quyền riêng tư hoặc khả năng truy cập chỉ là hướng khảo sát cho đến khi có cơ sở.
- [x] Với từng cải tiến, ghi đối tượng sử dụng, vấn đề, giải pháp, lợi ích, chi phí/phụ thuộc và phép đo thành công; tách giả thuyết cần hỏi người dùng khỏi phát hiện đã xác minh.
- [x] Xếp ưu tiên theo giá trị, độ chắc chắn và độ khó; đề xuất MVP cùng những mục để sau, tránh cam kết toàn bộ app gốc ngay từ bản đầu.
- [ ] Với dữ liệu cốt lõi, chọn phương án khả thi: nguồn được phép dùng, nguồn công khai phù hợp hoặc backend riêng. Liệt kê câu hỏi về quyền truy cập, độ phủ, tần suất cập nhật và chi phí cần xác minh.
- [x] So sánh các lựa chọn stack phù hợp với nhu cầu đã biết; đề xuất kiến trúc app/backend, cache, data contract và cách vận hành. Không mặc định stack gốc là lựa chọn cho app mới.
- [x] Viết tiêu chí nghiệm thu cho MVP và các cải tiến ưu tiên; lập danh sách quyết định cần người dùng chốt về đối tượng, nền tảng, phạm vi và ngân sách.

**Hoàn tất khi:** Có đặc tả sản phẩm có thể review, phạm vi MVP rõ, phương án dữ liệu với các phụ thuộc còn mở và backlog cải tiến có tiêu chí đo. Sau khi các quyết định sản phẩm được chốt, tạo kế hoạch triển khai riêng theo từng lát tính năng; chưa viết mã sản phẩm trong kế hoạch điều tra này.

## Mốc bàn giao và cách cập nhật

| Mốc | Nội dung review |
|---|---|
| M1 — sau giai đoạn 2 | Artifact, tech stack, bản đồ thành phần và giới hạn graph |
| M2 — sau giai đoạn 4 | Feature matrix, flow, API catalog và mô hình dữ liệu tĩnh |
| M3 — sau giai đoạn 5 | Kết quả runtime, sai lệch so với mã và phần chưa xác minh |
| M4 — sau giai đoạn 6 | MVP, cải tiến, phương án dữ liệu và đề xuất kiến trúc |

Sau mỗi nhiệm vụ, cập nhật checkbox và `docs/investigation.md` với kết quả, bằng chứng và câu hỏi tiếp theo. Các mốc là điểm báo cáo; tiếp tục công việc đã được giao trong phạm vi điều tra, chỉ hỏi khi thiếu thông tin quyết định hoặc gặp hành động cần người dùng xử lý.

**Bước thực hiện đầu tiên:** Giai đoạn 1 — chốt bộ APK và nguồn trích xuất. Chưa ước lượng lịch cố định trước khi biết độ obfuscation, mức đầy đủ của mã, khả năng chạy emulator và các phụ thuộc backend.

