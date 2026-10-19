# Lượt 6 — kiểm tra hợp đồng nguồn camera

Ngày 2026-10-14, 08:33:26 UTC. Script: `scripts/probe-camera-contract.py`. Bằng chứng: `evidence/camera/contract-pass6/`. Đây là **quan sát HTTP bằng probe độc lập**, không phải capture app; không có REA Evidence ID cho những GET này. Không gửi Authorization/cookie; User-Agent của công cụ điều tra. Không thay đổi app, quyền hay cấu hình thiết bị.

## Kết quả

| Phép thử GET trên `https://api.notis.vn/v4/` | Kết quả | File bằng chứng |
|---|---|---|
| `cameras/5deb576d1dc17d7c5515ad13/snapshot` | 200; 48.800 bytes; JPEG magic `ffd8ffe000104a4649460001` | `snapshot.json` |
| `cameras?lat=10.775708&lng=106.700359&distance=500` | 10 record; khoảng cách tính từ tọa độ tối đa ~497,80 m | `radius-500.json` |
| Cùng tâm, `distance=5000` | 89 record; xa nhất ~1845,64 m | `radius-5000.json` |
| Cùng tâm, `distance=10000` | 89 record; cùng thứ tự ID và body hash với mẫu 5000 | `radius-10000.json` |
| Cùng truy vấn 5000, thêm `limit=5` | Vẫn 89; cùng body hash | `limit-5.json` |
| Cùng truy vấn 5000, thêm `limit=5&page=2` | Vẫn 89; cùng body hash | `page-2-limit-5.json` |
| `cameras/bybbox?lat1=10.73&lng1=106.65&lat2=10.82&lng2=106.75` | 342 record | `bbox-wide.json` |

**Quan sát probe:** các response nearby có `distance` tăng dần. Khoảng cách này lệch tối đa ~2,06 m so với Haversine dùng bán kính Trái Đất 6.371.008,8 m trong mẫu 5000. **Suy luận:** đơn vị mét phù hợp với dữ liệu; chưa xác nhận công thức server hay quy tắc lọc.

**Quan sát probe + phép tính:** trong bbox rộng có 290 tọa độ cách tâm không quá 5000 m theo Haversine, trong đó 201 ID không có trong nearby 89. Bằng chứng `bbox-comparison.json`, `summary.json`. Không thể cam kết nearby trả tất cả camera trong 5 km. Hai endpoint có thể có quy tắc chọn khác nhau; chưa xác minh trạng thái camera, giới hạn server, radius bị giới hạn hoặc phân trang khác.

**Suy luận có giới hạn:** kết quả 90 ở lượt 2/5 và 89 lần này bác bỏ việc dùng số 90 quan sát được làm hằng số nghiệp vụ. Không đủ chứng minh server không có cap khác. Thử `limit/page` không có hiệu lực trong các request trên; không đủ chứng minh mọi cơ chế phân trang đều không tồn tại.

## Snapshot, cache và xác thực

Snapshot thử lại thành công không gửi credentials, body hash `c543fe2acd789e41b07c121ed3c1504a38edd2629483d7fa741ee0ff1b5efd12`. Chỉ lưu metadata/magic/hash, không lưu thêm ảnh. Không có header trong tập được giữ (`Content-Type`, `Content-Length`, `Cache-Control`, `ETag`, `Last-Modified`, `Expires`, `Age`, `Vary`, `Retry-After`) qua urllib. Không suy ra ảnh không cache; không có ETag để thử conditional GET snapshot. Các JSON list có weak ETag, chưa thử revalidation.

**Chưa xác minh:** request snapshot do Dart app gửi, headers bắt buộc, auth contract đầy đủ, cache TTL, conditional GET, retry, Dart caller. Lượt này không giải quyết capture TLS; giới hạn native provider ở lượt 5 vẫn giữ nguyên. Không gọi probe là traffic app và không tuyên bố đã đóng hợp đồng backend.

## Tác động lên spec

- Hiển thị số kết quả từ response, không hardcode 90; chưa có total đáng tin thì ghi “Đã tải N camera”.
- App mới cần hợp đồng radius/pagination rõ ràng từ backend được phép sử dụng. Kiểm thử phải có camera trong bán kính nhưng nằm ngoài trang đầu để tránh bỏ sót.
- Chu kỳ ~12 giây là cấu hình đề xuất từ mẫu runtime, không phải TTL hoặc hợp đồng snapshot đã xác minh.
- Đã tổng hợp phạm vi triển khai, trạng thái dữ liệu và tiêu chí nghiệm thu trong `rebuild-spec.md`; đây là bản dự thảo cho app mới, không phải xác nhận được phép tái sử dụng API gốc.
