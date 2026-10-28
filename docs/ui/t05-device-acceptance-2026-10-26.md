# Nghiệm thu T05 — Liquid Glass, accessibility và hiệu năng thiết bị

Báo cáo này tổng hợp lượt profile Android thật ngày 2026-10-25, các regression tự động và lượt iOS Simulator ngày 2026-10-26 cho issue #5. Golden/mockup HTML không được dùng làm bằng chứng renderer.

## Kết luận

T05 **được chấp nhận hoàn tất** theo phạm vi đã được người dùng điều chỉnh:

- Người dùng đã lược bỏ yêu cầu walkthrough TalkBack/VoiceOver. Cây accessibility và regression semantics/focus vẫn phải đạt; không suy rằng screen reader bằng âm thanh đã PASS.
- Raster p95 Android candidate là **18,536 ms**, cao hơn mục tiêu 16,7 ms. Người dùng đã xem số đo và trả lời **“chấp nhận hiệu năng như vậy”** ngày 2026-10-25; kết quả không bị viết lại thành đạt ngưỡng.
- Phạm vi đã chạy không bao gồm native Maps hoặc LIVE; các hạng mục đó thuộc ticket riêng.

## AC1 — Layout, theme, focus, labels và motion: **PASS theo phạm vi đã duyệt**

### Tự động

- `camera_a11y_layout_test.dart`: viewport 320/390dp, text scale 2, dark theme, reduced motion và nhãn Quan tâm.
- `camera_filters_test.dart`: ma trận 320/390/600 × text scale 1/2, modal trên keyboard và Back trả focus về trigger mà không xóa query.
- `camera_glass_controls_test.dart`: target tối thiểu 48×48, high contrast/opaque fallback, reduced motion và semantics control.

### Android thật

- realme RMX2205, Android 12/API 31, 360 logical px; profile ARM64.
- Đã kiểm Card/Grid/List, light/dark, modal quận và nhãn, detail/fullscreen/Back, lưới nhiều camera, landscape và font tối đa OEM 1.6.
- Hiệu ứng kính/modal và ảnh camera hiển thị; không quan sát shader exception hoặc crash trong 20 vòng.
- TalkBack chỉ xác nhận được focus viền xanh bằng TAB, không có xác nhận âm thanh. Mục này không được đánh PASS và sau đó đã được người dùng lược bỏ khỏi điều kiện chặn.

### iOS Simulator

- iPhone 17 Pro, iOS 26.1; Flutter 3.47.7/Dart 3.13.5; Impeller Metal.
- Bật đồng thời dark appearance, Increase Contrast, content size `accessibility-extra-large` và `ReduceMotionEnabled=1`; catalog, modal quận, detail và fullscreen vẫn thao tác được, media không mất và không có shader exception.
- Accessibility snapshot của modal chỉ expose các control trong modal (`Đóng`, các quận, scrim) cùng trạng thái selected; ảnh gốc nằm trong [`t05-ios-accessibility-2026-10-26/`](t05-ios-accessibility-2026-10-26/README.md).
- Lượt đầu phát hiện nút fullscreen expose `Đóng` ở cả label và tooltip, khiến native tree ghép thành `Đóng / Đóng`. Regression test đã đỏ với `tooltip='Đóng'`; commit `1c9f023` cho `CameraGlassIconButton` loại tooltip khỏi semantics nhưng giữ tooltip trực quan. Sau rebuild, native tree chỉ còn một button `Đóng`.
- Sau nghiệm thu đã khôi phục simulator về light, contrast disabled, content size large và Reduce Motion `0`.

## AC2 — Frame timing và bộ nhớ: **ĐÃ ĐO, NGƯỜI DÙNG CHẤP NHẬN**

Mỗi bản chạy 5 vòng warm-up rồi 20 vòng catalog → detail → fullscreen → Back → Back trên Android profile. Candidate là commit `cbd8ea0`, đã nằm trong lịch sử `main` hiện tại.

| Chỉ số candidate | Kết quả |
| --- | ---: |
| Frame đo được | 2.119 |
| UI/build p50 / p95 | 3,034 / 6,304 ms |
| Raster p50 / p95 | 11,364 / **18,536 ms** |
| UI / raster frame >16,7 ms | 24 / 162 |
| PSS vòng 0 / vòng 20 | 366,96 / 501,04 MiB |
| PSS tăng trong 20 vòng | 134,08 MiB |
| PSS idle 0/10/30 giây | khoảng 499,2 MiB, chưa giảm trong cửa sổ đo |

Số đo một lượt không đủ kết luận memory leak. Người dùng chấp nhận mức hiện tại; không tối ưu chất lượng/shader thêm trong T05. CSV, raw FrameTiming và dumpsys meminfo nằm trong [`device-2026-10-25-rmx2205/`](liquid-glass-refresh/device-2026-10-25-rmx2205/README.md).

## AC3 — Renderer và bằng chứng: **PASS trong phạm vi đã chạy**

- Ảnh Android là screenshot app thật cùng fixture trước/sau; iOS là screenshot trực tiếp từ simulator. Không dùng 12 mockup HTML để kết luận renderer.
- Không quan sát shader exception, crash hoặc mất media ở catalog/detail/fullscreen trong các lượt trên.
- Giới hạn được giữ rõ: không chứng nhận Maps/LIVE, screen reader âm thanh hay thiết bị iOS vật lý.

## Lệnh iOS chính

```sh
xcrun simctl ui <iphone-udid> appearance dark
xcrun simctl ui <iphone-udid> increase_contrast enabled
xcrun simctl ui <iphone-udid> content_size accessibility-extra-large
xcrun simctl spawn <iphone-udid> defaults write com.apple.Accessibility ReduceMotionEnabled -bool YES
flutter run -d <iphone-udid> --debug --dart-define=CAMERA_DEMO_MODE=true --no-resident
```

Thiết lập được đọc lại là `dark`, `enabled`, `accessibility-extra-large`, `1`. Cây native và screenshot được thu bằng `agent-device`; sau sửa nhãn, fullscreen trả một button `Đóng`.

## Kiểm tra hồi quy cuối

- Test mục tiêu `camera_a11y_layout_test.dart`, `camera_glass_controls_test.dart`, `camera_filters_test.dart` → **35/35 PASS**.
- `flutter analyze` → **No issues found**.
- `flutter test` → **244 PASS, 1 skipped**.
- Backend không đổi mã nguồn; không chạy lại suite backend cho thay đổi UI/semantics này.
