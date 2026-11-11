# N3-03 — Lệnh tiếng Việt ngoại tuyến

Bản đánh giá Android dùng **Zipformer Vietnamese 30M int8 (2026-02-09)**
qua **Sherpa-ONNX 2.0.1**. Trình nhận dạng xử lý toàn bộ lượt nghe trong bộ
nhớ. Dart chỉ điều phối kết quả khớp một trong sáu nhóm lệnh đã khai báo.

## Đóng gói APK

ZIP model và AAR là đầu vào của bản build, tải riêng theo các bước bên dưới.

1. Tải và giải nén [tarball model chính thức](https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-zipformer-vi-30M-int8-2026-02-09.tar.bz2).
   SHA-256 của tarball là `da8b637947091829d7ee9eda23da2a4ec7caa399233a3f4e34eb719fb2ea6b9b`.
2. Nén `encoder.int8.onnx`, `decoder.onnx`, `joiner.int8.onnx` và
   `tokens.txt` trực tiếp ở gốc của `zipformer-vi-30m-int8.zip`.
3. Tải [sherpa-onnx-2.0.1.aar](https://github.com/k2-fsa/sherpa-onnx/releases/download/v2.0.1/sherpa-onnx-2.0.1.aar).
   SHA-256 của AAR là `a8d09d1d32f3eb8520482c6d3d43fae674681c5b050385967c70a3c2c9bf0ee7`.

Chạy `flutter pub get` từ thư mục dự án. Sau đó chạy PowerShell từ
thư mục `android`, thay các đường dẫn mẫu bằng đường dẫn tuyệt đối:

```powershell
$entrypoint = (Resolve-Path ../lib/main_staging.dart).Path
.\gradlew.bat :app:assembleRelease `
  "-PseemateZipformerModelDir=C:\models\zipformer" `
  "-PseemateSherpaAar=C:\models\sherpa-onnx-2.0.1.aar" `
  "-Ptarget=$entrypoint"
```

`seemateZipformerModelDir` trỏ đến thư mục chứa ZIP. Thêm
`"-PseemateModelDir=C:\models\efficientdet"` để đóng gói nhận diện đồ vật
cùng OCR và giọng nói. Xem [cấu hình bản tích hợp](n3-integrated-realme-5i.md).
APK nằm tại `build/app/outputs/apk/release/app-release.apk` từ thư mục
dự án. Bản build thiếu model vẫn dùng được nút chạm và TalkBack.

Thẻ [model upstream](https://huggingface.co/hynt/Zipformer-30M-RNNT-6000h)
ghi CC BY-NC-ND 4.0. Dùng cấu hình này cho đánh giá nội bộ và rà soát
giấy phép trước khi phát hành. Runtime
[Sherpa-ONNX](https://github.com/k2-fsa/sherpa-onnx/blob/v2.0.1/LICENSE)
có giấy phép Apache 2.0 riêng.

## Kiểm thử trên máy

Chạm **Nói lệnh** và đợi máy rung rồi nói. App thu PCM mono 16 kHz
khoảng 5 giây theo cấu hình mặc định rồi mới giải mã. App tạm ngừng
TTS trước khi nghe và giữ âm thanh trong bộ nhớ. Hủy lượt nghe chặn
kết quả cũ. Khi từ chối quyền micro, nút chạm và TalkBack vẫn dùng được.

| Lệnh thử | Kết quả cần quan sát |
| --- | --- |
| Nhận diện đồ vật | Chuyển sang nhận diện và mở camera khi có quyền |
| Tìm chai nước | Mở tìm vật và chọn chai nước |
| Tìm ví tiền | Báo mục tiêu ngoài phạm vi 16 lớp, giữ chế độ hiện tại |
| Đọc văn bản | Mở preview, chờ lệnh Chụp |
| Chụp | Lấy một frame khi đang đọc văn bản. Ngoài chế độ này, hiển thị hướng dẫn |
| Dừng đọc | Dừng phát, hủy OCR đang xử lý và giữ phản hồi nhận diện ở trạng thái dừng |
| Quay lại | Về màn hình chọn chế độ, đóng camera và dừng công việc của chế độ trước |

Thử thêm câu ngoài danh sách và tiếng nền để phát hiện lệnh kích hoạt nhầm.

Thử khi bật chế độ máy bay và tắt Wi-Fi. Ghi thêm quyền micro bị từ chối,
hủy giữa lượt nghe, câu không hiểu, TalkBack đang bật và trạng thái cài đặt
sau khi đóng rồi mở lại app. Không lưu âm thanh hoặc transcript trong báo cáo.

Cài đặt giọng đọc và trạng thái đã xem hướng dẫn dùng kho SharedPreferences
của Android. Khi chưa có bản ghi mới, app thử đọc dữ liệu DataStore từ bản
cũ trong tối đa 3 giây. Bấm **Lưu** để ghi cài đặt vào kho mới. Bản đánh giá
ghim `shared_preferences_android` 2.4.28, bản dùng Pigeon qua kênh nền tảng
trước đợt chuyển sang JNI. Việc tải cài đặt chạy ngoài đường mở giao diện.

## Kết quả bản đánh giá

### Zipformer Vietnamese 30M int8 ngày 2026-11-11

- ZIP model dùng cho lần đánh giá có SHA-256
  `f387670d96444025ecd8e48c769b21cd8d5bf5b4bbbe388ec43d074c97be8a05`.
- APK `seemate-zipformer-vi-30m-int8-realme5i.apk`, SHA-256
  `de56025d2473b853cdfd7364eb43e7b01d6ca2730f087f522e85cc4aa2ebd421`.
  Build thành công, chữ ký hợp lệ, có model Zipformer, EfficientDet và
  thư viện Sherpa/ONNX. Manifest không có INTERNET. Bản đánh giá bỏ qua
  `lintVitalRelease` như cấu hình đánh giá trước.
- Đã cài và mở trên Realme 5i RMX2032, Android 10. Người dùng báo nhận
  giọng và chuyển lệnh thành hành động khá ổn định. Chưa có tỷ lệ nhận
  đúng theo lệnh, độ trễ, mức dùng bộ nhớ hay kết quả đầy đủ trong chế độ
  máy bay. Lần đánh giá này có `flutter analyze` sạch và 111 test qua.

### Bản build sau khi dọn mã nguồn

- APK `seemate-zipformer-only-realme5i.apk`, SHA-256
  `451bc069246838386c92ef0fbfc8fc2b47fc65ea33b5c7d7749816fe18280158`.
  Đã kiểm tra chữ ký, model Zipformer, EfficientDet, thư viện Sherpa/ONNX
  và manifest không có quyền INTERNET. Bản đánh giá bỏ qua `lintVitalRelease`.
  Kiểm thử giọng nói trên Realme ở trên thuộc bản APK trước đó.
