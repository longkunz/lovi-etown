# Catalog, cache, favorites và ca fallback có kiểm soát

## Catalog CG01 đã giải mã

`assets/catalog/tp_hcm.json.enc` dùng container `CG01` + nonce 12 byte + ciphertext + tag 16 byte, AES-256-GCM. `CatalogCrypto._secretKey` XOR hai mảng hằng 32 byte trong object pool. Probe chỉ đọc hai mảng giới hạn đúng độ dài sau khi kiểm tra instruction/prefix của ELF; key chỉ gửi dưới dạng binary vào collector private, không in ra hoặc đưa vào báo cáo.

Giải mã bằng Node crypto thành công, xác thực tag GCM; thử key sai bị từ chối và không tạo output. Plaintext 1.439.762 byte, SHA-256 `f1a6cacb5bcb54965b0e036b54d1a63e1edde2a52f45d4b3f5fd5f0350c793eb`. Plaintext/raw URL giữ private, summary ở [catalog-local-state-summary.json](../evidence/native/catalog-local-state-summary.json).

Top-level có `name`, `slug`, `provinceKey`, `api`, `count`, `fetchedAt`, `sourceApp`, `cameras`, `center`. Asset có **726 camera**, schema gần API và thêm `index`. Cả 726 ID đều có trong response API 900 camera. Chính xác tập ID asset = tập ID API trừ 174 ID unavailable local; không chỉ suy ra từ phép trừ số lượng.

## Cache và thứ tự load

Cache runtime: `/data/data/com.genius.cameragiaothong/app_flutter/catalog_tp_hcm_v6.json`, top-level `slug`, `provinceKey`, `fetchedAt`, `cameras`. File đã pull chứa 726 camera; tập ID khớp asset và API sau lọc unavailable.

Raw disassembly `HcmCameraCatalogRepository.ensureLoaded` (`0x68d338`) có các nhánh:

1. Có dữ liệu trong memory và không force → return sớm.
2. Đường tải mới gọi `UdrivexApiClient.fetchHcmCameras`, overlay district từ asset, lọc unavailable, set memory và ghi disk cache.
3. Nhánh fallback đọc disk cache, parse và chạy kiểm tra `_looksLikeStaleNotisCatalog`.
4. Cache không dùng được → `_loadAssetCameras`, qua `CatalogCrypto.decrypt` cho asset CG01.

Đã bổ sung ba ca lỗi DNS API để xác nhận cache được chấp nhận, cache bị thay bằng asset, và không-cache dùng asset; xem [catalog-fallback-runtime.md](catalog-fallback-runtime.md). Routine stale kiểm tra tối đa 40 URL theo Notis/ashx, không chứng minh TTL theo thời gian. TTL refresh đầy đủ còn mở. Không coi `fetchedAt` là timestamp của ảnh camera.

Nguồn disassembly: `evidence/native/dae-hcm-repository.txt`, `dae-catalog-crypto.txt`. DAE profile SDK unverified, pseudocode async có giới hạn; thứ tự trên dựa raw disassembly. Không phải kết quả Java source graph.

## Favorites đã đối chiếu key

`FavoritesStore` dùng `SharedPreferences.getInstance`, get/set StringList. File Android là `shared_prefs/FlutterSharedPreferences.xml`, key **`flutter.camera_favorite_ids`** (Dart key `camera_favorite_ids`). Giá trị ở runtime là prefix list của plugin rồi JSON array ID.

Ca đối chiếu với Phan Đăng Lưu – Phan Xích Long: trước 0 ID, bấm tim → 1 ID khớp chính xác trường **`id`**, khác `uniqueId`; bấm bỏ → về đúng array ban đầu. Ba snapshot XML chỉ giữ private. Có tăng bộ đếm review khi thêm favorite, không reset bộ đếm bằng sửa dữ liệu. `ProvinceCatalogFacade.resolveFavorites` có bước resolve qua catalog; chưa thử camera bị gỡ hoặc ID đổi sau refresh. Chưa xác định migration/sync đa thiết bị.

## Fallback khi nguồn chính lỗi DNS

Ca `backup-fault` fresh spawn, 200 giây: hook `getaddrinfo` thay duy nhất hostname `api.notis.vn` bằng tên `.invalid` trong tiến trình app. Không đổi DNS hệ thống, APK, server, token hoặc quyền VIP. Tác động bao gồm thumbnail Notis trong app, không chỉ camera đang mở.

Ghi 92 kết quả DNS lỗi, status 7; camera Phan Đăng Lưu – Phan Xích Long hiện “Không tải được hình ảnh” trong lúc probe còn hoạt động. Không có yêu cầu DNS tới backup host đã biết `camera.thongtingiaothong.vn`. Sau timeout probe tự gỡ; ảnh nguồn chính xuất hiện lại. [Summary](../evidence/runtime/dart-capture/fallback-fault-summary.json).

Kết luận giới hạn: **chưa thấy tự chuyển sang backup trong ca lỗi DNS này**. Không suy ra app không có fallback ở mọi failure mode: observer DNS không bao phủ socket dùng IP/cache, chưa thử HTTP 4xx/5xx hoặc ảnh placeholder. Sự tồn tại `backupCamera` trong model/cache không bảo đảm cơ chế failover hoạt động.

## Kiểm chứng

Scripts: `analyze-local-state.py`, `decrypt-catalog.mjs`, `summarize-fallback-fault.py`. Key/plaintext/raw prefs nằm dưới `dart-capture/private`, được git-ignore. Sai key bị reject; tập ID asset/cache/API đã so sánh; thao tác favorite được hoàn lại; fault chỉ sống trong thời gian collector. Bốn APK gốc được kiểm tra hash lại.
