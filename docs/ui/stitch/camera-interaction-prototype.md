# Prototype tương tác Camera — 16/10/2026

Mục tiêu: kiểm tra luồng danh sách → bottom sheet → viewer → quay lại, zoom và bố cục xoay ngang trước khi viết Flutter. Đây là prototype HTML dùng dữ liệu mẫu và JPEG local, không gọi API, không lưu state sau reload. Chưa phải nghiệm thu shader `liquid_glass_widgets` hoặc thiết bị thật.

## Mở bản thử

Mở trực tiếp [camera-interaction-prototype.html](camera-interaction-prototype.html) bằng Edge/Chrome, không cần server hoặc cài package. Tái dựng bằng `node scripts/ui/build-camera-interaction-prototype.cjs` từ workspace.

1. Chạm card camera để mở sheet; sheet chỉ có header, Quan tâm và ảnh, không toolbar hoặc text thời gian.
2. Chạm ảnh mở viewer. Pinch hoặc lăn chuột zoom 1–5×; double-tap/double-click chuyển fit/2.5×; kéo ảnh đã zoom.
3. Dùng nút thử “Xoay dọc / ngang viewer” trên desktop; trên mobile viewer đáp ứng viewport khi xoay thiết bị.
4. X/Esc đóng viewer về sheet; tiếp tục X/Esc/scrim hoặc vuốt handle xuống đóng sheet. Query, khu vực, mode và scroll của feed vẫn giữ.
5. Dùng controls ngoài khung điện thoại để thử light/dark, loading, lỗi ảnh và Quan tâm rỗng. “Thử lại” là mô phỏng chuyển lỗi sang ảnh đã tải, không request network.

Các controls và thông tin state ngoài khung điện thoại chỉ dùng review. Không đưa chúng vào UI sản phẩm. Artboard trên Stitch là ảnh trạng thái tĩnh; file HTML ở trên mới có tương tác. Timestamp in sẵn trong JPEG nguồn giữ nguyên.

## Bằng chứng kiểm tra

- Headless Edge: mở modal khóa tương tác nền, double-tap zoom, layout ngang, Esc viewer → sheet → list, thử lại lỗi ảnh, Quan tâm rỗng; không có page error. Xem [manifest](camera-interaction-prototype-manifest.json).
- Edge với touch mô phỏng: pinch hai điểm tăng zoom 3×; viewport 390×844 → 844×390 fit viewer; đóng giữ khu vực đã chọn. Xem [touch verification](camera-prototype-touch-verification.json).
- Đã xem screenshot viewer ngang, sheet dark, lỗi ảnh và Quan tâm rỗng. Không coi kiểm tra mô phỏng là kiểm tra xoay/pinch trên điện thoại thật.

## Cần review trước Flutter

Độ rõ chữ của glass ở light/dark; ảnh có cần ẩn header viewer sau chạm; cảm giác zoom/pan và đóng modal trên thiết bị thật. App Flutter cần dùng chung controller/bytes và không nhân polling khi mở viewer hoặc xoay. Prototype chưa mô phỏng network, cache, infinite pagination hoặc polling; hướng UI đã chốt trong spec vẫn giữ.

Prototype chưa có kết luận phê duyệt từ người dùng. Không chuyển code thử HTML vào `mobile/lib/`; root workspace không có Git để lưu throwaway branch, nên lưu artifact riêng cùng tài liệu này.
