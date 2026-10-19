# App-Check: tạo phía client đã đối chiếu runtime

App tự tạo header tùy biến `App-Check` bằng RSA, không phải kết luận suy ra từ tên header Firebase. Trong phiên `api33auth2`, plaintext trước UTF-8 có dạng:

```text
saigon_traffic_cam###<issued_ms>###<expires_ms>###290
```

`expires_ms - issued_ms = 600000` (10 phút). Kết quả mã hóa được Base64 thành 344 ký tự. SHA-256 của kết quả trả về từ `base64Encode` trùng SHA-256 header HTTP gửi tới `/api/hls/ha-noi`, response 200. Token thô chỉ nằm trong capture private; [summary](../evidence/runtime/dart-capture/app-check-summary.json) giữ trường thời gian và hash.

## Bằng chứng tĩnh

DAE v0.1.13 phân tích `libapp.so` x64, compressed pointers. Provenance và digest công cụ: `evidence/native/dae-tool-provenance.json`; raw disassembly: `dae-app-check-class.txt` trong cùng thư mục. Đây là bằng chứng local, không phải REA Evidence ID. Profile tương thích `dart/3.11.6` được DAE đánh dấu **unverified**, không dùng để thay kết luận engine Dart 3.11.0 từ binary.

| Hàm | RVA | Hành vi quan sát trong disassembly |
|---|---|---|
| `AppCheckToken.buildApiHeaders` | `0x62de2c` | Tạo headers, gồm App-Version 290, User-Agent tự đặt Dart/3.12 |
| `AppCheckToken.getToken` | `0x62df5c` | Cache token/expiry; nhánh force; ghép payload; UTF-8 → RSA → Base64 |
| `AppCheckToken._loadPublicKey` | `0x63ab28` | Nạp `assets/public.pem`, parse RSA public key |
| `RSA.encrypt` | `0x62e28c` | Encrypt qua cipher instance |

Nhánh cache so sánh thời điểm hiện tại với expiry trừ Duration 60.000.000 microseconds (60 giây); expiry được tạo từ issued time cộng `0x927c0` milliseconds (600.000). Đây là lifecycle **phía client**. Chưa chạy ca chờ hết 10 phút hoặc force refresh. Pseudocode async của DAE không thể hiện đầy đủ resume body; kết luận trên dựa disassembly và runtime, không dựa riêng pseudocode.

## Kiểm chứng runtime

`scripts/frida/observe-app-check.js` chỉ đọc dữ liệu. Bốn probe kiểm tra 32 byte prefix so với ELF gốc trước khi attach. Probe UTF-8 và Base64 lọc đúng return address của caller `getToken`, tránh thu chuỗi của SDK khác. Layout string 8/16 trên runtime đã đọc được payload đúng cấu trúc; layout 4/8 từ template ban đầu cho độ dài 0, nên phiên đầu `api33auth` không dùng làm kết quả xác nhận.

Phiên `api33auth2` có 1 getToken, 1 payload, 1 ciphertext; không có lỗi decode; ciphertext khớp header. Có 1 sự kiện `PKCS1Encoding._encodeBlock`, nhưng probe này bao phủ tiến trình và chưa ghi ancestry: chưa coi riêng sự kiện đó là chứng minh đầy đủ biến thể padding của token.

Tái hiện collector (tên capture phải mới):

```powershell
python scripts/build-app-check-symbols.py
& 'C:/Users/longhv/AppData/Local/Python/pythoncore-3.14-64/python.exe' scripts/capture-dart-tls.py --serial emulator-5580 --seconds 65 --name newauth --app-check
python scripts/parse-dart-http.py newauth
```

Không replay token, không thử giả token hoặc sửa quyền backend. Chưa biết enforcement, đồng bộ clock phía server, quota hoặc điều kiện nhận public key mới. Cơ chế này là mô tả app gốc; app mới cần API và cơ chế xác thực riêng.
