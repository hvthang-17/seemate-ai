# Mốc nhận diện v1 trên Realme 5i

Ngày ghi nhận 2026-11-10. Phạm vi v1 gồm 16 lớp trong bảng nhãn của app.
Ví, chìa khóa và bánh mì thuộc đợt mở rộng. Bàn được đánh giá theo nhãn
`dining table`. Xem [bảng nhãn](../../../lib/features/object_detection/domain/v1_detection_catalog.dart)
và [giao thức đánh giá](../../evaluation-protocol.md).

| Thành phần | Cấu hình |
| --- | --- |
| Thiết bị | Realme 5i RMX2032, Android 10, API 29, arm64-v8a |
| APK đánh giá | `seemate-v1-16-realme5i.apk`, Android 1.0.0 (1) |
| SHA-256 APK | `cc8211530da2df95043fb065b039bc5f4b3ac49601b22c15b1b9ae745c9117ff` |
| Runtime | MediaPipe Tasks Vision 1.1.0, CPU |
| Model | EfficientDet-Lite0 int8, 320 × 320 |
| SHA-256 model | `0720bf247bd76e6594ea28fa9c6f7c5242be774818997dbbeffc4da460c723bb` |
| Nhận diện | Confidence ≥ 0,50, IoU ≥ 0,50, 2 quan sát cùng vùng trong tối đa 3 frame đã xử lý |
| Tìm vật | Confidence ≥ 0,50, IoU ≥ 0,50, 3 frame liên tiếp cùng vùng |

Phần Flutter biên dịch từ mã v1. Gói đánh giá dùng manifest và thư viện
Android của APK đánh giá trước, với phần Flutter đã cập nhật và chữ ký debug.
Đã kiểm tra chữ ký, SHA-256 của model đóng gói, quyền CAMERA và APK không
yêu cầu quyền INTERNET.

## Kết quả ghi nhận

| Kiểm tra | Kết quả |
| --- | --- |
| Phân tích mã và kiểm thử | `flutter analyze` không có lỗi. 85 test qua, gồm bộ chọn 16 lớp và ca nhiều vật trong cùng khung. |
| Cài và mở trên thiết bị | ADB báo cài thành công. Android mở MainActivity và giao diện SeeMate xuất hiện. |
| Cốc trái, laptop phải | Ảnh màn hình do người dùng cung cấp cho thấy đồng thời cốc bên trái (75%) và laptop bên phải (75%). |
| Chai trái, laptop phải | Chưa ghi nhận. |

Ảnh màn hình ghi nhận một thời điểm. Confidence là điểm model hiển thị.
Chưa đo độ trễ, độ lặp lại hoặc tỉ lệ nhận diện trên tập cảnh.

## Cách lặp lại

Dùng camera sau, giữ nguyên vị trí vật, khoảng cách, hướng máy và ánh sáng
giữa hai model. Lặp lại cảnh cốc trái + laptop phải, rồi thử khung trống,
chai riêng, chai trái + laptop phải, và thêm cốc ở giữa. Ghi vật và vùng
thực tế, vật và vùng app hiện, confidence và số lần thử. Có thể rút USB
trước khi thử. Nếu cần so sánh độ trễ, dùng máy thứ hai quay cả lúc đưa
vật vào khung và màn hình app, rồi lấy chênh lệch giữa hai mốc trong video.
Nếu có ảnh đánh giá được phép dùng, giữ ảnh và annotation ngoài Git,
gắn ID cảnh cố định và dùng lại đúng tập cảnh cho cả hai model.

### Phiếu thử nhanh sau khi rút USB

**APK dùng cho đợt thử preview thu gọn ngày 2026-11-10**

- File `seemate-v1-16-realme5i-compact-preview.apk`. SHA-256
  `ff80e1381032ea05dff219ee83667d41e251d2cd3cd7015a7a09828fb086cb8b`.
- Phần Flutter biên dịch mới và đóng gói với model, tài nguyên Flutter và
  thư viện Android đã đối chiếu từ APK v1 ở trên. Chữ ký debug, model và
  quyền APK đã được kiểm tra.
- Đã cài đè, mở app và bật Nhận diện đồ vật trên RMX2032. Giao diện báo
  máy ảnh đang hoạt động. Người dùng xác nhận bản thu gọn đã vượt qua
  các cảnh thử dưới đây. Chưa có số liệu từng lượt hoặc confidence cho
  bản thu gọn. Ảnh cốc và laptop ở trên thuộc APK v1 trước đó.

| Cảnh | Vật và vùng thực tế | Kết quả cần ghi mỗi lượt |
| --- | --- | --- |
| R5I-01 | Cốc trái, laptop phải | Cả hai tên và vùng, hoặc vật nào bị bỏ sót hay nhận sai |
| R5I-02 | Chai ở giữa | Có chai hay không, vùng và confidence hiển thị |
| R5I-03 | Chai trái, laptop phải | Tên và vùng của cả hai, kể cả mục nhận dư |
| R5I-04 | Khung trống, không có vật mục tiêu | Có kết quả nhận nhầm hay không |

Thử ba lượt mỗi cảnh và ghi từng lượt thay vì chỉ chọn ảnh đẹp nhất.
Ghi thêm APK, hướng máy và điều kiện ánh sáng. Với bố cục thu gọn, ghi
preview có dễ quan sát không và có đọc được kết quả bên dưới không.

Các ca thử trên chỉ dùng để kiểm tra nhanh tích hợp. Đánh giá đủ 16 lớp cần
tập cảnh độc lập và số mẫu theo giao thức để tính precision, recall và
độ đúng vùng. Chưa có số liệu đủ để kết luận đạt nghiệm thu.
