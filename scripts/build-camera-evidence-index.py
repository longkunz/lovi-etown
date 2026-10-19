"""Build a report index from retained REA CLI envelopes and MCP Evidence."""
import json, hashlib
from pathlib import Path
root = Path(__file__).resolve().parents[1]
folder = root / 'evidence/camera'
lines = ['# Evidence index — camera', '', 'Ngày: 2026-10-14. REA screenshot chỉ chứng minh frame tại thời điểm chụp. Thao tác ADB được mô tả trong docs/camera-spec.md; không tự gắn hash APK cho screenshot.', '', '| File | Operation | Evidence ID |', '|---|---|---|']
for p in sorted(folder.glob('*.json')):
    j = json.loads(p.read_text(encoding='utf-8-sig'))
    if not isinstance(j, dict):
        continue
    d = j.get('data', j)
    if not isinstance(d, dict) or not d.get('evidence_id'):
        continue
    lines.append(f"| [{p.name}]({p.name}) | {d.get('operation', '')} | `{d['evidence_id']}` |")
lines += ['', '## File hashes', '', '| File | SHA-256 |', '|---|---|']
for p in sorted(folder.rglob('*')):
    if p.is_file() and p.name != 'evidence-index.md':
        rel = p.relative_to(folder).as_posix()
        lines.append(f'| [{rel}]({rel}) | `{hashlib.sha256(p.read_bytes()).hexdigest()}` |')
lines += ['', '## Tái hiện', '', '- Dùng REA CLI 6.4.0, JDK 21 và JAR JADX Headless MCP 0.7.1 hiện có. Đặt REA_JADX_MCP_JAR trong process trước các lệnh Android tĩnh.', '- Tĩnh: `rea inspect-android-package <base.apk> --format json --full-output`; `rea search-android-classes <base.apk> Camera --format json --full-output`.', '- REA MCP: `open_binary` split ARM64 rồi `extract_artifact`; giữ manifest/hash và bản sao libapp.so riêng. Chạy `python scripts/extract-camera-strings.py` để tái tạo literal có file offset.', '- Runtime: đặt REA_ADB_PATH tới adb; `rea inspect-adb-package emulator-5554 com.fts.notis --format json --full-output`; `rea capture-adb-screen emulator-5554 --output-directory <thư mục mới> --format json --full-output`.', '- Từ trang chính chọn Camera; xem Bản đồ; chọn marker Gò Dưa khi ở vùng đó; bấm tim; vào Quan tâm; mở dòng; đóng khung; bỏ tim; trở lại Bản đồ; mở Khu vực và chọn Nguyễn Huệ. Xem chi tiết trong spec.', '- Các tọa độ tap trong lượt này phụ thuộc màn 1600×900 và trạng thái sẵn có, không phải test UI ổn định. Danh sách quan tâm đã trở lại rỗng sau thử nghiệm; bản đồ cuối lượt ở Nguyễn Huệ.', '- `rea-search-results.json` chỉ chụp bản đồ sau Back, không phải bằng chứng kết quả tìm kiếm. `rea-area-selected.json` còn ở sheet, kết quả chọn thực nằm trong `rea-area-result.json`.', '- Chạy `python scripts/build-camera-evidence-index.py` sau khi thu thêm evidence.', '']
lines += ['## Lượt 2', '', 'Storage/probe HTTP/Frida là evidence do script thu; không có REA Evidence ID nếu không xuất hiện trong bảng đầu. Ba GET là analyst probes, không phải traffic app. Bản đồ cuối lượt 1 ở Nguyễn Huệ; sau restart lượt 2 app ở splash. Quan tâm đã được cleanup về rỗng bằng SharedPreferences API; xem docs/camera-runtime-pass2.md và favorite-cleanup.txt.', '']
lines += ['## Lượt 3 — đính chính và bổ sung', '', 'Rút lại suy luận kẹt splash: vuốt lên thấy menu và mở Camera được. Đã tái hiện Quan tâm phục hồi qua process restart; evidence hợp lệ là rea-pass3-restored và storage-pass3-added-verified. Đã đo counter/socket, thử REJECT riêng UID app tới một host rồi xóa rule, cleanup Quan tâm bằng UI về rỗng. Tìm kiếm chưa có dòng kết quả; chọn điểm sau từ chối prompt vị trí chưa xác nhận thành công. Chi tiết: docs/camera-runtime-pass3.md.', '']
lines += ['## Lượt 4', '', 'Đã đo lifecycle snapshot, hook attempted GET LIVE và đối chiếu lỗi cleartext bằng REA/JADX đúng runtime APK. Mẫu Java caller/manifest không được gán sang APK workspace khác hash. Thử quyền app vị trí rồi trả FINE/COARSE về denied; không bật dịch vụ vị trí toàn thiết bị. LIVE phát và chọn điểm thành công chưa xác minh. Xem docs/camera-runtime-pass4.md.', '']
lines += ['## Lượt 5', '', 'Flow Xung quanh đã chạy đầu-cuối trên emulator-5580 Android 13 với cùng runtime APK set kéo bằng REA từ emulator-5554. GPS denied, chọn thủ công nhận địa chỉ, xác nhận ra 90 camera và mở preview. Tìm chữ có ErrorLog route 404; Android 9 reverse geocoding ném Service not Available. REA q3.r.onMethodCall có nhánh SDK sync/async. Snapshot HTTP app đầy đủ vẫn chưa capture; các probe timeout/memory vắng candidate không được coi là bằng chứng traffic app. Xem docs/camera-runtime-pass5.md.', '']
(folder / 'evidence-index.md').write_text('\n'.join(lines), encoding='utf-8')
print(f'Indexed evidence in {folder}')
