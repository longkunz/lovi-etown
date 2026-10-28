# Bằng chứng T05 trên iOS Simulator — 2026-10-26

Thiết bị: iPhone 17 Pro simulator, iOS 26.1. Trong cả bốn ảnh: dark appearance, Increase Contrast, content size `accessibility-extra-large` và Reduce Motion đều đang bật.

| File | Bằng chứng |
| --- | --- |
| [`01-dark-large-text-catalog.png`](01-dark-large-text-catalog.png) | Catalog ở cỡ chữ accessibility, control vẫn thao tác được và nội dung cuộn được. |
| [`02-dark-large-text-modal.png`](02-dark-large-text-modal.png) | Modal quận có opaque/high-contrast fallback, title/close/options đọc được. |
| [`03-dark-large-text-detail.png`](03-dark-large-text-detail.png) | Detail giữ media rõ, segmented control và metadata đọc được. |
| [`04-dark-large-text-fullscreen.png`](04-dark-large-text-fullscreen.png) | Fullscreen giữ ảnh, title wrap và nút đóng. |

Accessibility snapshot trước sửa expose button fullscreen là `Đóng / Đóng`; sau khi tooltip bị loại khỏi semantics, snapshot native chỉ còn `Đóng`. Không file nào được dùng để tuyên bố VoiceOver bằng âm thanh đã PASS.
