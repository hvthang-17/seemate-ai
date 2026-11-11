# Kiểm tra OCR, giọng nói và Dừng đọc

## Cấu hình

- Nhận diện v1 dùng EfficientDet-Lite0 int8. OCR dùng ML Kit Latin
  `com.google.mlkit:text-recognition:16.0.1` đóng gói trong APK.
- OCR lấy một frame YUV420 trong bộ nhớ từ phiên camera hiện tại. Cầu nối
  Android chuyển các plane có stride sang NV21 và chuyển góc xoay cho ML Kit.
  Cách này dùng chung phiên và định dạng camera của nhận diện. Ví dụ
  camera Android của [google_mlkit_commons](https://github.com/flutter-ml/google_ml_kit_flutter/blob/develop/packages/google_mlkit_commons/README.md)
  nhận NV21 một plane.
- TTS dùng engine Android và giọng vi-VN đã cài hỗ trợ ngoại tuyến.
  Cầu nối gửi kèm ID từng lượt phát để bỏ callback từ yêu cầu đã dừng.
  Callback Dart của [flutter_tts](https://github.com/dlutton/flutter_tts/blob/master/lib/flutter_tts.dart)
  không mang ID lượt phát.

## Ca kiểm tra trên cùng APK

| Ca | Cách thử | Kết quả cần quan sát |
| --- | --- | --- |
| Quyền camera | Từ chối quyền, rồi mở cài đặt và cấp lại | Có hướng dẫn khi bị từ chối, preview mở lại sau khi cấp |
| Đổi chế độ | Nhận diện → Đọc văn bản → Tìm đồ vật | Preview mở theo chế độ, kết quả cũ không phát sau khi đổi |
| OCR tiếng Việt | Hướng camera vào chữ in rõ dấu và bấm Chụp và đọc văn bản | Văn bản xuất hiện và có giọng đọc khi máy đã cài giọng ngoại tuyến |
| Dừng đọc | Bấm khi đang phát đoạn OCR dài, rồi chủ động chụp lại | Giọng dừng, yêu cầu cũ không phát lại, lần chụp mới vẫn dùng được |
| Ngoại tuyến | Bật chế độ máy bay và tắt Wi-Fi, lặp lại nhận diện và OCR | Model chạy tại chỗ. Nếu thiếu giọng vi-VN ngoại tuyến, app vẫn hiển thị văn bản và hướng dẫn cài giọng |

Ghi SHA-256 của APK, Android, engine/giọng đã chọn và kết quả từng ca.
Chỉ ghi văn bản kiểm thử phi cá nhân và kết quả tổng hợp.

## Kết quả Realme 5i

- Thiết bị RMX2032, Android 10. APK `seemate-v1-n3-integrated-realme5i.apk`,
  SHA-256 `bca34ba531e276d7b4210cde2e36a78835bc4b508599329210e35ea899e44a24`.
- APK đánh giá build thành công bằng Gradle với `lintVitalRelease` tạm bỏ qua
  do cache thiếu `lint-gradle`. Đã xác minh chữ ký, model EfficientDet-Lite0,
  tài nguyên OCR Latin và thư viện OCR arm64. Manifest có quyền camera và
  không yêu cầu INTERNET.
- `flutter analyze` sạch. 98 test tự động qua. Kiểm thử tập trung xác nhận
  hủy OCR, ngắt hàng đợi TTS, đổi chế độ và từ chối quyền với camera giả.
- Trên APK tích hợp, ADB cài thành công. Với quyền đã cấp, chế độ Nhận diện
  mở camera. Chuyển sang Đọc văn bản hiện nút Chụp và đọc văn bản. Danh sách
  Tìm đồ vật mở được, nhưng kết nối USB mất trước khi xác nhận preview tìm vật.
- ROM từ chối lệnh ADB thu hồi quyền camera. Ca từ chối/cấp lại trên máy thật
  cần thực hiện trong Cài đặt Android.

### Kết quả người dùng xác nhận

- N3-01: Realme 5i phát được giọng `vi-VN` ngoại tuyến khi nhận diện vật.
  Sau khi chụp văn bản, app đọc được một đoạn dài.
- N3-02: Người dùng xác nhận luồng chụp và nhận dạng văn bản hoạt động trên
  máy thật. Chưa ghi điều kiện mạng của ca OCR hoặc số liệu tỷ lệ lỗi ký tự.
- Chưa có kết quả bấm **Dừng đọc** giữa lượt phát hoặc số đo thời gian ngắt.
  Báo cáo của người dùng chưa kèm checksum APK dùng cho các ca trên.
