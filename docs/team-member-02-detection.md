# N2 — Nhận diện đồ vật, vị trí và tìm vật

Tài liệu giao việc chi tiết cho người số 2. Đọc cùng
[kế hoạch nhóm](team-work-plan.md), [PRD](../tasks/prd-seemate-ai.md),
[code standards](code-standards.md) và [quy trình đánh giá](evaluation-protocol.md).
Các module, tên class/file gợi ý bên dưới là thiết kế dự kiến, chưa có trong
checkout. Chốt API ở G0 trước khi tạo implementation; không coi tên gợi ý là
SDK hoặc interface đã tồn tại.

## 1. Kết quả N2 phải chịu trách nhiệm

Từ một frame hợp lệ do N1 cung cấp, module N2 trả danh sách nhận diện có class,
confidence, bounding box, vị trí tương đối và thông tin ổn định. Trong chế độ
tìm vật, chỉ trả match đúng object key yêu cầu. Module chạy trên thiết bị,
không gửi ảnh lên mạng, không tự mở camera và không trực tiếp phát giọng nói.

Ba sản phẩm bàn giao riêng biệt:

1. Baseline chạy thật để nhóm tích hợp pipeline sớm.
2. Logic confidence/stability/zone/target matching có test xác định được.
3. Model cuối và kết quả đánh giá minh bạch; baseline chạy được không đồng nghĩa
   đã đáp ứng đủ lớp hoặc chất lượng MVP.

## 2. Kiến thức phải tìm hiểu và bài kiểm tra hiểu biết

| Chủ đề | Cần hiểu để làm việc gì | Bài thực hành/đầu ra quan sát được |
| --- | --- | --- |
| Dart bất đồng bộ và ownership | `Future`, stream, xử lý lỗi, cancellation; không trả kết quả sang session mới | Fake detector trả chậm; đóng session rồi hoàn tất fake; chứng minh kết quả cũ không được phát |
| Clean Architecture và contract | Domain không phụ thuộc camera/runtime; data adapter thực thi contract; GetIt chỉ tại composition | Vẽ luồng frame → detector adapter → domain result → N1, chỉ rõ kiểu vào/ra và owner |
| Riverpod 2 cơ bản | Đọc được cách N1 gọi use case qua provider, override fake khi test | Đọc Home provider tests và giải thích vì sao module không tự tạo notifier/UI thứ hai |
| Object detection | Phân biệt classification và detection, class ID/label, confidence, bounding box, NMS | Đọc metadata model, xuất bảng object key → class ID → label → trạng thái hỗ trợ |
| Tensor input/output | Shape, dtype, normalization/quantization, channel order, output tensors | Ghi hợp đồng tensor của đúng artifact; test fixture có kích thước/giá trị sai trả typed failure |
| Hệ tọa độ ảnh | Pixel plane/stride, rotation, resize, crop hoặc letterbox; phép biến đổi ngược | Tạo box tổng hợp ở trái/giữa/phải; chứng minh mapping đúng qua mọi rotation mà G0 hỗ trợ |
| Temporal filtering | Confidence, tracking liên kết detection qua frame, stability, target absent | Chuỗi frame giả ổn định/jitter/mất target cho kết quả đúng chính sách đã chốt |
| Đánh giá ML | IoU, TP/FP/FN, precision/recall, micro/macro, data leakage | Tự chấm một bộ box nhỏ có duplicate/sai class và đối chiếu expected counts |
| Dataset/model artifact | Gán nhãn, split độc lập, nguồn/license, version/checksum, fine-tune/export | Manifest ghi rõ nguồn và test set tách theo vật thể/buổi chụp, không chia frame gần nhau qua các split |
| Tài nguyên Android | Inference async không tự bảo đảm không block UI; CPU/backend, thời gian khởi tạo/đóng | Báo thời gian trên máy thật, backend/thread settings và tài nguyên được giải phóng |

Không cần học toàn bộ thuật toán huấn luyện trước N2-01. Cần đọc hiểu input,
output và artifact trước; bổ sung kiến thức training khi xử lý lớp còn thiếu.
Package/runtime phải được nhóm kiểm tra tương thích và pin version; không sao
chép code API từ phiên bản khác rồi tự sửa file cấu hình của N1.

Đọc mã có sẵn theo thứ tự:

- [GetCities](../lib/features/home/domain/use_cases/get_cities.dart): use case.
- [CityRepository](../lib/features/home/domain/repositories/city_repository.dart)
  và [implementation](../lib/features/home/data/repositories/city_repository_impl.dart): ranh giới domain/data.
- [Home providers](../lib/features/home/presentation/home_providers.dart) và
  [provider tests](../test/features/home/home_providers_test.dart): dependency override.
- [Kiến trúc mục tiêu](system-architecture.md#target-design-camera-and-ai-assistance-not-implemented): luồng assistance dự kiến.

## 3. Phạm vi file và chức năng cần code

N2 sở hữu `lib/features/object_detection/`, `assets/models/object_detection/`,
`tool/model_evaluation/`, `test/features/object_detection/` và
`docs/evaluation/object_detection/`. Tên file gợi ý, xác nhận tại G0:

| Vị trí dự kiến | Trách nhiệm |
| --- | --- |
| `domain/models/` trong feature | Detection result/configuration riêng feature; dùng lại object key, frame, zone/failure types đã chốt trong shared contract |
| `domain/repositories/` | Contract nội bộ nếu feature cần; không tạo bản sao contract dùng chung của N1 |
| `domain/use_cases/detect_objects.dart` | Phối hợp inference và trả kết quả theo session/configuration |
| `domain/use_cases/match_target.dart` | Chỉ chọn object key yêu cầu; phân biệt target absent và unsupported |
| `domain/services/position_mapper.dart` | Đổi box đã chuẩn hóa thành trái/giữa/phải theo biên cấu hình |
| `domain/services/detection_stabilizer.dart` | Xác nhận object/vị trí qua các frame được xử lý; reset khi đổi session/target |
| `data/sources/` | Adapter runtime, đọc model/metadata, chuẩn bị tensor, inference, giải mã output, đóng runtime |
| `data/repositories/` | Thực thi contract, chuyển lỗi runtime thành lỗi có kiểu |
| `assets/models/object_detection/` | Artifact được phép phân phối, labels và manifest nguồn/license/checksum |
| `tool/model_evaluation/` | Scoring/export số liệu phi cá nhân; không biến app thành trình ghi ảnh |
| `test/features/object_detection/` | Test preprocessing/box transform/mapping/stability/search/cancellation bằng fixture/fake |

Không tự mở `presentation/` để làm Home/camera overlay. N1 sở hữu UI và feature
state của session. Các thuật toán tùy chỉnh chỉ triển khai sau khi kiểm tra
runtime/package đã hỗ trợ chưa; ghi lý do nếu phải tự làm reusable utility.

**N2 không code:** camera controller/permission, router, microphone, TTS/STT,
settings persistence, speech duplicate suppression, localization text, shared
GetIt registrations, Android config, `pubspec.yaml`/lockfile. Không sửa ARB,
PRD hoặc shared contracts trực tiếp; gửi yêu cầu N1. Không dùng HTTP/cache/queue
starter để truyền hoặc lưu frame. Không tính khoảng cách hoặc đưa chỉ dẫn đi an toàn.

## 4. Hợp đồng bắt buộc với N1 và N3

G0 phải trả lời bằng chữ ký Dart và test, không chỉ bằng sơ đồ:

- Ai cấp/phóng frame buffer; frame còn hợp lệ đến khi nào; detector có được giữ
  tham chiếu sau khi Future hoàn tất không. Quy tắc copy/ownership phải rõ.
- N1 cung cấp pixel format/planes/stride và metadata orientation/crop. N2 chuẩn
  bị tensor theo artifact và chuyển box về hệ tọa độ G0. Chỉ một bên áp dụng
  mỗi transform; không xoay ảnh hai lần hoặc lấy zone từ preview đã crop khác.
- Mọi result chứa frame/session ID theo contract; kết quả đến sau cancel không
  được gọi thành công cho request mới. `dispose`/close idempotent theo G0.
- N1 sở hữu tốc độ cấp frame và active mode; N2 báo busy/readiness theo contract,
  không tạo hàng đợi frame vô hạn. Chốt chính sách bỏ frame khi inference bận.
- Với nhiều instance cùng class, G0 chốt tiêu chí chọn target và liên kết qua
  frame. Không mặc định cộng ba detection khác nhau thành một target ổn định.
- N2 quyết định confidence, stability, zone và target matching. N1 quyết định
  có chuyển kết quả hợp lệ sang speech coordinator không. N3 sở hữu suppression
  theo object key + zone và playback; N2 không làm thêm bộ chống đọc lặp khác.
- N2 trả object key/zone có kiểu, không hard-code câu tiếng Việt hay gọi TTS.
  N1/N3 dùng localization và speech contract để tạo/phát phản hồi.

Nếu thiếu field hoặc API không đủ dùng: gửi ví dụ input/output và test lỗi cho
N1; N1 mở PR contract, cả N2/N3 review, merge trước khi đổi adapter. Khi N1 chưa
có camera, N2 dùng fake frame/fixture hợp lệ và test harness trong phạm vi mình;
không chờ UI mới làm được unit test, cũng không chiếm camera ownership để demo.

## 5. Task N2-01 — baseline detector

**Điều kiện bắt đầu:** G0 và PR dependency/assets declaration của N1 đã merge.
N2 gửi trước package/version candidate, model path/size/license và cấu hình cần
thêm để N1 chuẩn bị; không tự sửa file chung.

**Cần code/làm:**

1. Kiểm tra artifact EfficientDet-Lite0 baseline: checksum, metadata, tensors,
   labels, normalization, output và quyền phân phối.
2. Viết runtime adapter với initialize/readiness/detect/close theo G0; báo
   missing/corrupt model, invalid frame và runtime failure bằng kiểu đã chốt.
3. Chuẩn bị tensor, giải mã class/confidence/box, áp dụng transform ngược;
   chỉ áp dụng NMS nếu đúng output contract cần nó, tránh NMS lặp vô ý.
4. Viết manifest và bảng support; ghi rõ baseline chưa có Wallet/Keys/Bread.
5. Chạy một fixture biết trước và live input khi camera N1 sẵn sàng; đo riêng
   initialization và inference, không gọi chúng là latency toàn tác vụ.

**Test tối thiểu:** model/frame không hợp lệ; dtype/shape mismatch; label ID ngoài
map; confidence/box bất thường; box transform; cancel khi inference đang chạy;
close hai lần; request sau close. Không chỉ test một ảnh có chai nước.

**Bàn giao:** adapter source/tests, artifact manifest, input/output contract,
report máy/Android/backend/commit và danh sách support/missing. Đạt PR module
khi adapter chạy cục bộ, test pass, không crash/leak khi close/cancel và không
claim đủ MVP. Chưa có bằng chứng thiết bị thì giữ draft theo cổng nhóm.

## 6. Task N2-02 — confidence, vị trí và tìm vật

**Đầu vào:** detections đã decode, configuration và target object key tùy mode.
**Đầu ra:** kết quả có kiểu cho recognition/search, zone và readiness/stability;
không có side effect âm thanh.

**Cần code/làm:** lọc confidence; map box center qua biên cấu hình; chọn/giữ
instance ổn định theo G0; target matching; reset buffer khi session/target đổi;
trả không đủ tin cậy/không thấy target/không hỗ trợ đúng quy ước. Ba processed
frames liên tiếp là giá trị pilot, không phải ba frame camera bất kỳ đã bỏ qua.

**Bảng test bắt buộc:**

| Tình huống | Kết quả phải chứng minh |
| --- | --- |
| Confidence dưới/bằng/trên ngưỡng | Rule biên đúng cấu hình, không có magic value rải rác |
| Tâm box trái/giữa/phải và đúng biên | Zone đúng cùng hệ tọa độ sau rotation/crop |
| Target chai nhưng chỉ có sách | Không trả thành công tìm chai |
| Object key không thuộc support map | Unsupported khác target absent |
| Hai instance cùng class đổi vị trí | Policy chọn/ghép instance xác định, không tự cộng nhầm stability |
| Jitter, mất một frame, đổi target/mode | Reset/giữ stability đúng G0; không rò trạng thái session cũ |
| Cancel trong khi đang xử lý | Không có result hợp lệ cho session đã kết thúc |

**Bàn giao:** use cases/services, test matrix và expected values. Đạt khi logic
chạy bằng fake deterministic, N1 tích hợp qua contract mà không sửa thuật toán,
N3 nhận được key/zone cần cho speech và không có suppression thứ hai tại N2.

## 7. Task N2-03 — model cuối, dữ liệu và chất lượng

Danh mục phải giữ đủ 19 lớp: Phone, Wallet, Keys, Backpack, Bottle, Cup, Apple,
Banana, Bread, Chair, Table, Book, Remote, Laptop, Keyboard, Mouse, Clock,
Scissors, Umbrella. Kiểm tra nhãn thật thay vì giả định chuỗi ứng dụng là class ID.

**Cần làm:** lập bảng coverage; thu/gán nhãn bổ sung; kiểm tra license/consent;
split theo vật thể/buổi chụp/phòng; fine-tune hoặc thay model nếu baseline không
đáp ứng; export artifact mobile; đo lại artifact đã export/quantize. Ngân sách
200–300 ảnh/lớp cần train thêm chỉ là pilot, không bảo đảm đủ dữ liệu.

Khóa test set trước khi chỉnh confidence. Có người thứ hai kiểm annotation.
Không đưa ảnh từ cùng video gần nhau sang train và test; không thay test set
để loại cảnh làm model nhận sai. Không commit dataset cá nhân/lớn vào Git.

**Test/bằng chứng:** TP/FP/FN và support từng lớp, precision/recall, negative
scenes, box/zone mapping; model checksum/license/labels; sample counts và những
điều kiện khó. Theo [protocol](evaluation-protocol.md#detection-and-relative-position-scoring),
fixed-threshold precision/recall không phải mAP. Precision ≥90%, recall ≥80%
tại IoU ≥0.5 là mục tiêu pilot cần xác nhận; phải chốt cách áp dụng từng lớp
hay aggregate trước final evaluation. Không coi confidence 0.50 là 50% accuracy.

Đạt task model cuối khi đủ coverage và có bằng chứng đáp ứng ngưỡng đã thống
nhất. Nếu thiếu lớp hoặc không đạt, báo blocker, có thể push report/source dạng
draft; không đánh dấu N2-03 hoàn thành hoặc tự cắt phạm vi PRD.

## 8. Task N2-04 — đo trên build tích hợp

**Điều kiện:** N1-04 đã merge, có APK/checksum cố định, protocol/config/test
manifest khóa. Phối hợp N1 để chạy đúng ba profile thiết bị đang có, không tự
coi emulator thay điện thoại thật.

N2 thực hiện bộ cảnh detection/zone/search; N1 điều khiển UI/camera session,
N3 chịu speech coordinator. Ghi đúng commit/model/device, số mẫu, warm/cold,
miss/false match/time-out và độ trễ từ frame hợp lệ đến phản hồi đúng. Đánh giá
box/zone trước suppression và kết quả spoken live riêng; không loại lần lỗi
khỏi mẫu số để làm độ trễ đẹp. Timing TTS phải đối chiếu audible output theo
protocol, không chỉ thời điểm enqueue.

**Bàn giao:** report phi cá nhân dưới `docs/evaluation/object_detection/`, bảng
class/condition/device, checklist search/detection/zone, limitations và defect
ID/owner. N1 tổng hợp user acceptance; N2 hỗ trợ chuẩn bị vật thể/ground truth
và xác định đúng/sai tác vụ tìm vật, không tự công bố MVP nghiệm thu.

## 9. Checklist trước push PR sẵn review

- Đúng task ID, file ownership và commit nền; dependency/contract PR đã merge.
- Có unit/fake tests cho logic và failure/cancel paths; có bằng chứng máy thật
  khi task cần runtime. Ghi rõ mức đã đo: adapter, live pipeline hay final model.
- Không sửa `pubspec`, Android, router, ARB, shared contract hoặc DI chung.
  DI wiring do N1 thực hiện; test module bằng dependency/fake, không phụ thuộc
  registration chưa được merge. Báo source annotations để N1 sinh DI sau đó.
- Artifact có source/license/checksum; report không có ảnh/âm thanh/secret hay
  payload người dùng. Model quá lớn cần thống nhất cơ chế phân phối với N1 trước.
- Đính kèm lệnh và kết quả analyzer/test; chạy build theo cổng chung nếu PR thay
  adapter/runtime platform. Chưa đủ kiểm tra thì để WIP/draft, không claim done.

Các lệnh hiện dùng được từ root sau khi project dependencies/generated code
đã chuẩn bị theo [quick start](quick-start-guide.md):

```sh
flutter analyze
flutter test
```

Lệnh focused **chỉ dùng sau khi thư mục test dự kiến đã được tạo**:

```sh
flutter test test/features/object_detection/
```

N1 review PR N2 theo kế hoạch nhóm. N2 đồng thời review phần N3 với trọng tâm
contract/session, không chồng speech và bằng chứng OCR/voice; không tự duyệt
PR của mình. Task hoàn tất là đủ tiêu chí và review/merge, không phải chỉ push code.

## 10. Gói bàn giao để người khác dùng được

Mỗi PR ghi: task ID; yêu cầu PRD; API/version sử dụng; object/label map; ví dụ
input/output phi cá nhân; cách initialize/detect/cancel/close; dependency/assets
N1 cần khai báo; test command/result; device/commit/model checksum; lỗi còn mở.
N1 nhận adapter và failure map để wiring; N3 nhận object keys/zone policy từ
contract, không nhận raw frame hoặc bị yêu cầu gọi runtime detection.

Chưa chốt ở thời điểm giao việc: artifact/runtime version cuối, nhãn/ID thật,
camera input transform G0, thiết bị cụ thể và ngưỡng sau pilot. N2 phải đưa các
điểm này vào G0/feasibility với N1/N3, không tự đoán rồi sửa API giữa chừng.
