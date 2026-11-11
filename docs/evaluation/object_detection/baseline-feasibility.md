# N2 — Khảo sát baseline nhận diện đồ vật

Đối chiếu artifact ngày 2026-11-09 cho N2-01 và N2-03. Bảng dưới đây xác định
nhãn nhúng trong model và phần dữ liệu còn thiếu theo
[PRD §9.2](../../../tasks/prd-seemate-ai.md#92-object-classes-and-vietnamese-phrase-mapping)
và [§9.6](../../../tasks/prd-seemate-ai.md#96-open-decisions-and-validation-gaps).

## Artifact đề xuất

| Mục | Kết quả khảo sát |
| --- | --- |
| Nhà phát hành và phiên bản | Google MediaPipe, EfficientDet-Lite0 lượng tử hóa int8, TensorFlow Lite v1. URL cố định theo [mẫu chính thức của Google](https://github.com/google-ai-edge/mediapipe-samples/blob/main/examples/object_detection/raspberry_pi/setup.sh). |
| Nguồn artifact | [`efficientdet_lite0.tflite` int8 v1](https://storage.googleapis.com/mediapipe-models/object_detector/efficientdet_lite0/int8/1/efficientdet_lite0.tflite). |
| Kích thước đầu vào | `320 × 320` theo [tài liệu Object Detector](https://developers.google.com/edge/mediapipe/solutions/vision/object_detector#efficientdet-lite0-model-recommended). |
| Label map | `labels.txt` nhúng trong artifact có 90 dòng, gồm 80 nhãn COCO và 10 vị trí `???`. Bảng bên dưới dùng thứ tự của tệp nhúng. [Danh mục công khai của Google](https://storage.googleapis.com/mediapipe-tasks/object_detector/labelmap.txt) |
| SHA-256 và kích thước file | `0720bf247bd76e6594ea28fa9c6f7c5242be774818997dbbeffc4da460c723bb`, 4.602.795 byte. |
| Giấy phép artifact | Chưa xác nhận điều khoản phân phối chính file `.tflite`. Cần bằng chứng từ nhà phát hành và ghi attribution/notice áp dụng trước khi đóng gói. |
| Tensor đầu vào | `uint8 [1,320,320,3]`, scale `0.0078125`, zero point `127`. |
| Tensor đầu ra | Hai tensor `float32` có shape `[1,19206,90]` và `[1,19206,4]`. Model có `DETECTOR_METADATA`. Kiểm tra adapter bằng runtime hiểu metadata này trước khi diễn giải class và box. [Schema TensorFlow Lite](https://raw.githubusercontent.com/tensorflow/tensorflow/master/tensorflow/compiler/mlir/lite/schema/schema.fbs) |
| Thiết bị | Realme 5i `RMX2032`, Android 10, `arm64-v8a`, `MemTotal` 3.728.932 kB. Đã chạy model trên CPU với công cụ benchmark TensorFlow Lite. |

## Đo inference trên Realme 5i

Ngày 2026-11-09, chạy [APK benchmark TensorFlow Lite ARM64](https://github.com/tensorflow/tensorflow/blob/master/tensorflow/lite/g3doc/performance/measurement.md#android-benchmark-app)
có SHA-256 `2f8e4bd51671013e49f0a043d162bb717b1ed0a6e09a89afdd2c41a367373f08`.
Dùng artifact nêu trên, đầu vào ngẫu nhiên do công cụ tạo, CPU XNNPACK hai luồng,
5 lượt warm-up và 30 lượt đo với `--warmup_min_secs=0 --min_secs=0`.

| Chỉ số | Kết quả |
| --- | ---: |
| Khởi tạo | 66,51 ms |
| Inference đầu tiên | 73,83 ms |
| Trung bình 30 lượt | 70,75 ms |
| Trung vị | 70,19 ms |
| P95 | 73,09 ms |

Kết quả xác nhận runtime chạy được graph trên điện thoại này. Phép đo chưa bao
gồm lấy frame, decode detection, TTS hay đo độ chính xác trên ảnh đại diện.

## Runtime cho adapter Android

`object_detection` trên pub.dev hiện yêu cầu Flutter 3.47.5 trở lên và dùng
artifact float32 mặc định. Máy phát triển đang dùng Flutter 3.47.1 và phép đo
trên Realme dùng artifact int8 v1. Bước thử adapter nên dùng MediaPipe Tasks
Vision trên Android với đúng artifact int8, rồi đối chiếu nhãn, score và box
trên ảnh mẫu trước khi quyết định dependency production.
[Yêu cầu package Flutter](https://pub.dev/documentation/object_detection/latest/) · [MediaPipe Object Detector cho Android](https://developers.google.com/edge/mediapipe/solutions/vision/object_detector/android)

## Kiểm tra ảnh thật ngày 2026-11-10

Dùng đúng SHA-256 model nêu trên, MediaPipe Tasks Python 1.2.2 trên Windows,
CPU XNNPACK và ngưỡng 0,50. Đọc JPEG theo hướng EXIF, giữ kích thước ảnh gốc.
Tọa độ chuẩn hóa theo thứ tự trái, trên, phải, dưới và được chặn trong [0, 1].

| Ảnh nguồn | Kích thước | Nhãn và điểm tin cậy | Bounding box |
| --- | --- | --- | --- |
| [Chai Coca-Cola Blāk, CC0](https://commons.wikimedia.org/wiki/File:Coca-Cola_Bl%C4%81k_Bottle.jpg) | 3024 × 4032 | `bottle` 0,7539 | (0,2880; 0,0481; 0,6247; 0,9802) |
| [Chai Coca-Cola thủy tinh, CC0](https://commons.wikimedia.org/wiki/File:A_glass_bottle_of_Coca-Cola.jpg) | 903 × 3051 | `vase` 0,7695 và `dining table` 0,5000 | `vase` (0,0897; 0,0016; 0,9369; 0,8823) |
| [Ảnh nhiều chai, CC0](https://commons.wikimedia.org/wiki/File:Coca-Cola_bottles_(27962750037).jpg) | 4957 × 3305 | `dining table` 0,5234 | (0,0000; 0,0024; 1,0000; 0,9879) |

Box đầu bao quanh chai và dư một phần nền dưới đáy. Hai ảnh còn lại không có
nhãn `bottle` đạt ngưỡng. Adapter lọc `vase` vì nằm ngoài danh mục MVP.
Đây là phép thử RGB tĩnh trên Windows, tách khỏi kiểm tra camera YUV420 Android
và phép đo chất lượng trên tập dữ liệu độc lập.

## APK Android đánh giá cục bộ

Xem [mốc v1 trên Realme 5i](v1-realme-5i-baseline.md) để đối chiếu phiên bản,
checksum và kết quả thiết bị khi nâng cấp model.

Thư mục do người chạy cung cấp chứa đúng file `efficientdet_lite0.tflite`.
Sau khi xác minh SHA-256, có thể build bản đánh giá bằng PowerShell.

```powershell
$modelDir = (Resolve-Path '.dart_tool/seemate-n2/model').Path
$entryPoint = (Resolve-Path 'lib/main_staging.dart').Path
Push-Location android
try {
    .\gradlew.bat :app:assembleRelease "-PseemateModelDir=$modelDir" "-Ptarget=$entryPoint" '-Ptarget-platform=android-arm64'
} finally {
    Pop-Location
}
```

Chỉ cấu hình đánh giá này đưa MediaPipe Tasks Vision 1.1.0 và model vào APK.
Manifest của cấu hình này loại quyền INTERNET. Bản build thường trả trạng
thái thiếu model. Cần giải quyết quyền phân phối artifact và chính sách metrics
trước khi chọn runtime phát hành. [Thông báo quyền riêng tư của MediaPipe Tasks](https://developers.google.com/edge/mediapipe/solutions/privacy) · [Trao đổi về giấy phép weights](https://github.com/google-ai-edge/mediapipe/issues/6306)

Ngày 2026-11-10, cả build thường và build đánh giá đều tạo APK thành công.
Đã kiểm tra APK thường không chứa model hay thư viện MediaPipe. APK đánh giá
có thư viện JNI, đúng SHA-256 của model và quyền CAMERA. Kiểm tra manifest
đóng gói xác nhận quyền INTERNET đã được loại. APK đánh giá đã cài và mở được
trên Realme 5i `RMX2032`, Android 10.

## Đối chiếu phạm vi v1 với 19 object key ban đầu

Vị trí tính từ 0 trong `labels.txt` và giữ nguyên các dòng `???`. Cột ID
tham chiếu đến [danh mục COCO của TensorFlow](https://github.com/tensorflow/models/blob/master/research/object_detection/data/mscoco_label_map.pbtxt).
Xác nhận giá trị class mà runtime thực sự trả về qua metadata và fixture trước
khi dùng số trong bảng cho adapter.

| Object key PRD | Nhãn Google | Vị trí dòng | COCO ID | Mức bao phủ theo danh mục |
| --- | --- | ---: | ---: | --- |
| Phone | `cell phone` | 76 | 77 | Có cho điện thoại di động |
| Wallet | — | — | — | Thiếu |
| Keys | — | — | — | Thiếu |
| Backpack | `backpack` | 26 | 27 | Có |
| Bottle | `bottle` | 43 | 44 | Có cho chai |
| Cup | `cup` | 46 | 47 | Có |
| Apple | `apple` | 52 | 53 | Có |
| Banana | `banana` | 51 | 52 | Có |
| Bread | — | — | — | Thiếu |
| Chair | `chair` | 61 | 62 | Có |
| Table | `dining table` | 66 | 67 | Một phần, chỉ có nhãn bàn ăn |
| Book | `book` | 83 | 84 | Có |
| Remote | `remote` | 74 | 75 | Có |
| Laptop | `laptop` | 72 | 73 | Có |
| Keyboard | `keyboard` | 75 | 76 | Có |
| Mouse | `mouse` | 73 | 74 | Có cho chuột máy tính |
| Clock | `clock` | 84 | 85 | Có |
| Scissors | `scissors` | 86 | 87 | Có |
| Umbrella | `umbrella` | 27 | 28 | Có |

Danh mục cho thấy 15 ánh xạ trực tiếp, một ánh xạ hẹp và ba lớp thiếu. Với
`Table`, N2 thử riêng bàn ăn, bàn học/làm việc và bàn thấp trong nhà. Nếu model
cuối vẫn chỉ phù hợp với bàn ăn, báo khoảng trống cho phạm vi `Table` trong PRD.

## Kiểm tra tiếp trước khi nối baseline

1. N2 tải artifact ngoài repo, ghi kích thước byte và SHA-256 bằng
   `Get-FileHash -Algorithm SHA256 -LiteralPath efficientdet_lite0.tflite`.
   Lấy danh sách tệp đi kèm bằng `python -m zipfile -l efficientdet_lite0.tflite`,
   rồi đọc label map và metadata bằng công cụ LiteRT. Lưu bằng chứng giấy phép
   và manifest cùng phiên bản trước khi N1 khai báo asset.
2. N2 xác nhận dtype, shape, scale/zero point của input, thứ tự/shape của output,
   cách biểu diễn box và class index từ chính artifact. Dùng fixture có lớp ở hai
   phía của một dòng `???` để phát hiện lỗi lệch chỉ số.
3. N1 chuyển frame có format, planes/stride, kích thước gốc và góc xoay theo
   [hợp đồng frame](../../../lib/shared/assistance_contracts/frame_session_contract.dart).
   N2 chuyển sang RGB, ghi rõ resize/crop/padding và đảo phép biến đổi để trả
   box chuẩn hóa trong hệ tọa độ frame đã dựng thẳng. Thử cả frame ngang và dọc.
4. N2 chạy fixture với CPU trên điện thoại Android thật, ghi máy, API, runtime,
   hash, class/box/score và lỗi. Lặp lại ở chế độ máy bay sau khi cài build có
   model bundled. Đo theo [protocol](../../evaluation-protocol.md) khi có build
   tích hợp và giữ bằng chứng baseline riêng với model nghiệm thu.

## Pilot dữ liệu cho Wallet, Keys và Bread sau v1

- N2 chốt hướng dẫn nhãn và kiểm tra chéo một lô nhỏ trước khi thu đủ khoảng
  200–300 ảnh có nhãn mỗi lớp cần bổ sung. Đây là ngân sách thu thập ban đầu
  theo PRD. Ghi nguồn, giấy phép hoặc đồng ý sử dụng, mã vật thể, phòng, phiên
  chụp và điều kiện ảnh trong manifest. Giữ ảnh ngoài Git.
- `Wallet` lấy ví gập, ví dài và ví khóa kéo, mở/đóng, nhiều chất liệu. Thêm ca
  âm có túi xách và bao điện thoại. `Keys` lấy chìa đơn và chùm chìa trên nhiều
  bề mặt, có phản sáng và che khuất. Thêm kẹp giấy, móc khóa rỗng và vật kim
  loại nhỏ làm ca âm. `Bread` lấy bánh mì ổ, bánh mì lát và bánh mì nhỏ, có ca
  bị che một phần. Tách rõ bánh mì khỏi bánh ngọt, bao bì rỗng và món sandwich
  trong hướng dẫn nhãn trước khi thu ảnh.
- Đa dạng vật thể thật, góc, khoảng cách, ánh sáng và độ lộn xộn trong phòng.
  Gán box cho mọi vật mục tiêu theo hướng dẫn chung. Kiểm tra box lỗi, nhãn thiếu
  và bản trùng. Chia train/validation/test theo vật thể, phòng hoặc phiên chụp để
  tránh các frame gần nhau rơi vào hai tập. Chốt cảnh và manifest test độc lập
  trước khi tinh chỉnh confidence, stability và chống lặp.
- Fine-tune hoặc thay baseline trong đợt mở rộng, giữ 16 lớp v1 khi bổ sung lớp.
  Đo lại lớp cũ để phát
  hiện suy giảm và báo TP/FP/FN, precision/recall theo từng lớp, ca âm và zone
  accuracy theo protocol. Model v1 cần được đo trên 16 lớp trong APK tích hợp
  để làm mốc so sánh cho đợt mở rộng.
