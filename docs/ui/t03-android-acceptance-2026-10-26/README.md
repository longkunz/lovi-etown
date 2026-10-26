# Bằng chứng thiết bị T03 — 2026-10-26

Môi trường: Android Emulator `sdk_gphone64_arm64`, Android 16, API 36; mã nghiệm thu tại commit `df1a997`.

| Ảnh | Nội dung xác nhận |
| --- | --- |
| [`01-favorite-after-restart.png`](01-favorite-after-restart.png) | Sau force-stop/mở lại, khu Quan tâm và thẻ catalog cùng giữ biểu tượng yêu thích. |
| [`02-fullscreen-zoom.png`](02-fullscreen-zoom.png) | Viewer toàn màn hình sau gesture pinch zoom 2x. |
| [`03-fullscreen-landscape.png`](03-fullscreen-landscape.png) | Viewer giữ đúng nội dung sau khi xoay ngang 1280×720. |
| [`04-real-backend-camera.png`](04-real-backend-camera.png) | Camera thật `Hàm Nghi - Phó Đức Chính` render snapshot qua backend proxy. |

Các ảnh chỉ chứa UI fixture hoặc camera giao thông công cộng; không chứa API key, URL upstream hoặc dữ liệu cá nhân.
