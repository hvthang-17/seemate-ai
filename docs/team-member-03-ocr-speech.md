# N3 — OCR, giọng nói và lưu cài đặt

Tài liệu giao việc chi tiết cho N3, đọc cùng [kế hoạch nhóm](team-work-plan.md),
[PRD](../tasks/prd-seemate-ai.md) và [quy trình đánh giá](evaluation-protocol.md).
Đây là chức năng cần xây dựng; repository hiện chưa có OCR, TTS, STT hay settings
MVP. Các tên lớp/file bên dưới là đề xuất để chốt tại G0, không phải API đã có.

## 1. Kết quả N3 chịu trách nhiệm

Sau khi hoàn tất, N3 bàn giao các module có thể gọi qua contract để:

1. Nhận một ảnh từ N1, OCR chữ in tiếng Việt trên thiết bị và trả kết quả.
2. Đọc văn bản bằng giọng tiếng Việt đã cài, dừng/hủy được và không chồng tiếng.
3. Chỉ nghe lệnh khi người dùng chủ động kích hoạt; trả hành động và object key.
4. Lưu/khôi phục cài đặt được PRD cho phép, không cần tài khoản.
5. Chặn thông báo detection trùng tại một speech coordinator duy nhất.

N3 không bàn giao giao diện camera/settings; N1 xây UI và kết nối các module
này. N3 không huấn luyện model đồ vật hay tính trái/giữa/phải; đó là N2.

## 2. Kiến thức phải tìm hiểu và cách tự kiểm tra

| Chủ đề | Cần hiểu để làm gì | Bài thực hành trước task chính |
| --- | --- | --- |
| Dart async, Future/Stream, typed results | Kết quả có thể về sau khi người dùng dừng hoặc đổi mode | Fake thao tác đang chạy; cancel session; hoàn thành Future cũ và chứng minh không phát speech/kết quả session mới |
| Clean Architecture và DI | Contract không phụ thuộc plugin; implementation thay bằng fake được | Dùng fake OCR/TTS trong test, không cần Firebase/GetIt production hoặc điện thoại |
| Riverpod 2 và ownership | N1 giữ mode/provider; module N3 không tạo bản state nghiệp vụ thứ hai | Giải thích ai gọi start/stop, ai dispose, event nào N1 cần theo dõi |
| ML Kit OCR Latin/bundled | Đọc tiếng Việt không đợi tải model sau khi cài | Pilot với chữ có dấu và airplane mode; ghi package/native configuration và kết quả, không chỉ ảnh demo đẹp |
| Định dạng ảnh Android | Pixel format, row/pixel stride, rotation/crop ảnh hưởng đầu vào OCR | Đưa fixture xoay các góc vào bộ chuyển đổi; chứng minh metadata đúng, không đọc nhầm buffer đã được N1 giải phóng |
| Android TTS và tài nguyên giọng | Giọng vi-VN có thể thiếu hoặc yêu cầu mạng | Kiểm tra readiness và chọn giọng offline; mô phỏng thiếu engine/voice, không âm thầm đổi sang giọng sai |
| Speech recognition ngắn | STT phụ thuộc máy; text nhận về chưa phải command hợp lệ | Fake các câu lệnh được hỗ trợ/không hiểu/không hỗ trợ; trả enum/object key, không tự gọi router |
| Đồng thời âm thanh | TTS/STT/TalkBack có thể cản nhau hoặc STT nhận giọng ứng dụng | Test stop trong lúc đang đọc, bắt đầu nghe khi đang nói, callback cũ sau cancel; kiểm tra thêm máy thật |
| Persistence cục bộ | Load/save/default, dữ liệu lỗi và restart | Fake store lỗi/thiếu key; xác nhận default hợp lệ, save lỗi được báo, load lại không mất thiết lập hợp lệ |
| CER và đo độ trễ | Có dấu, empty reference và thời điểm âm thanh thật | Tự tính CER cho ví dụ sai dấu; phân biệt callback enqueue với âm thanh thực bắt đầu/dừng |

Chỉ xem bài thực hành là đạt khi có test hoặc ghi nhận pilot tái lập được.
Nếu chưa hiểu định dạng ảnh, cancellation hoặc offline voice thì làm pilot trước,
không mở rộng ngay thành giao diện hoàn chỉnh.

### Mã hiện có cần đọc

- [Code standards](code-standards.md), [architecture](system-architecture.md):
  ranh giới state/DI và phần camera/AI chỉ là target design.
- [Home providers](../lib/features/home/presentation/home_providers.dart) và
  [provider tests](../test/features/home/home_providers_test.dart): cách đọc
  dependency và override bằng fake.
- [Permission contract](../lib/core/permissions/permission_service.dart): enum
  quyền hiện có; không thêm hệ thống xin quyền cạnh tranh với N1.
- [Bootstrap](../lib/app.dart), [DI](../lib/core/di/get_it.dart): hiểu nơi N1 wiring,
  không sửa trực tiếp để chạy module của mình.
- [English ARB](../lib/shared/i18n/arb/app_en.arb): N1 sở hữu localization; N3 gửi
  danh sách key/thông báo cần bổ sung, không hardcode thông báo UI production.

## 3. Phạm vi code và phần không được tự sửa

| Phần | N3 phải code | N3 không làm |
| --- | --- | --- |
| OCR | Chuyển input G0 sang ảnh plugin, chạy OCR, trả text/empty/failure và hủy request | Không mở camera thứ hai, không lưu ảnh, không tự đọc kết quả OCR |
| TTS | Readiness, voice offline, speak/stop/cancel, queue và trạng thái | Không tự quyết định mode hay target; không điều khiển TalkBack hệ thống |
| Suppression | Một policy tại speech coordinator, kiểm thử thời gian bằng fake clock | Không tạo bản sao suppression trong OCR adapter hoặc N2 |
| STT/command | Session ngắn, availability, parser trả action/object key | Không nghe liên tục mặc định, không tự cloud fallback, không tự chuyển route |
| Settings | Repository/domain load/save/default và validation | Không xây settings screen hoặc mutable settings state trùng provider N1 |
| Tích hợp | Bàn giao source implementation, factory/registration requirements, fake và tests | Không sửa pubspec/lock, Android, router, DI registry, ARB hay contract chung của N1 |

Không log text OCR, transcript giọng nói, raw audio hoặc ảnh. Raw OCR output là
dữ liệu chức năng để hiển thị/đọc trong phiên, không phải localization template
và không phải lịch sử được phép lưu.

### Cây file dự kiến

G0 chốt tên chính thức; không tạo tất cả file nếu một concern chưa cần tách.

| Vị trí dự kiến | Trách nhiệm |
| --- | --- |
| `lib/features/text_reading/data/sources/mlkit_text_source.dart` | Gọi plugin OCR; không import widget/router |
| `lib/features/text_reading/data/repositories/text_reading_repository_impl.dart` | Chuyển lỗi platform thành typed failure của contract |
| `lib/features/text_reading/domain/use_cases/read_printed_text.dart` | Tác vụ một request OCR, tham chiếu contract chung thay vì định nghĩa lại |
| `lib/core/speech/offline_tts_adapter.dart` | Plugin TTS, readiness, voice, callback, stop/dispose |
| `lib/core/speech/speech_coordinator.dart` | Playback queue, interruption, suppression và loại request cũ |
| `lib/core/speech/voice_command_adapter.dart` | Phiên STT chủ động, kết quả nhận dạng, lỗi/availability |
| `lib/core/speech/vietnamese_command_parser.dart` | Câu lệnh/alias → enum và object key đã thống nhất |
| `lib/features/settings/domain/` | Use case/validation settings, dùng contract/value type chung |
| `lib/features/settings/data/` | Persistence adapter và repository implementation |
| `test/features/text_reading/`, `test/core/speech/`, `test/features/settings/` | Tests cho source/domain của N3; không đặt widget test của settings UI tại đây |
| `docs/evaluation/text_speech/` | Manifest, phương pháp và số liệu phi cá nhân; chưa có kết quả tại thời điểm lập kế hoạch |

Contract dùng chung do N1 giữ ở `lib/shared/assistance_contracts/`. Nếu thiếu field,
N3 nêu use case, input/output, failure và test ảnh hưởng để N1 mở PR contract;
không tự tạo một interface cùng ý nghĩa trong thư mục riêng.

## 4. Luồng phối hợp để không code trùng

**OCR:** N1 nhận thao tác → lấy một ảnh và request/session ID → N3 OCR → trả kết
quả → N1 kiểm tra phiên còn hiệu lực, hiển thị text và gửi đúng một yêu cầu đọc
đến speech coordinator N3. OCR adapter tuyệt đối không tự gọi speak.

**Detection:** N2 trả kết quả ổn định/object key/zone → N1 chọn phản hồi và cung
cấp nội dung tiếng Việt từ localization → coordinator N3 kiểm tra suppression
và phát. N2 không gọi TTS; N3 không tính lại confidence hoặc zone.

**Command:** N1 kích hoạt nghe sau kiểm tra quyền → N3 trả command có kiểu → N1
chuyển mode/gọi action. Parser dùng cùng object keys với N2 qua contract G0;
không dùng raw model class ID làm từ khóa thoại.

**Settings:** N1 yêu cầu load/save qua repository N3 → N1 quản lý trạng thái UI/
provider và chuyển cấu hình vào coordinator. N3 không điều khiển slider/dialog.

N1 điều phối app lifecycle và đổi mode; N3 chịu stop/cancel/dispose tài nguyên
mình tạo theo lệnh đó. Callback/event của N3 chỉ cập nhật trạng thái đã thống
nhất, không mở dialog/snackbar hay navigation. G0 phải thống nhất tương tác
stop trong lúc nghe/đọc, session reset, buffer release và event subscription.

## 5. N3-01 — Offline TTS, stop và speech coordinator

**Đầu vào/phụ thuộc:** G0 đã merge; N1 đã thêm dependency/config cần thiết;
contract speech có fake và tập thông điệp thử nghiệm phi cá nhân.

**Phải thực hiện:**

1. Khởi tạo TTS adapter; phân biệt ready, thiếu engine/voice, voice cần mạng,
   initialization failure và disposed. Cung cấp dữ liệu để N1 hướng dẫn cài voice.
2. Chọn giọng vi-VN offline có sẵn; kiểm tra airplane mode trên máy ghi rõ engine.
3. Xây một coordinator sở hữu queue. G0 quy định thay thế/ưu tiên request;
   Stop phải hủy playback và queue cũ, không để callback hoàn thành làm phát tiếp.
4. Suppression detection theo object key + zone, phạm vi session và policy
   reappearance/đổi vùng đã chốt G0; nhận settings từ N1. Không áp dụng máy móc
   suppression detection khiến người dùng không thể chủ động đọc lại văn bản.
5. Dừng engine, đóng callback/subscription và chống gọi sau dispose; không dispose
   engine shared hai lần. Cung cấp playback events cần cho N1 và benchmark.

**Test bắt buộc:** ready/không có voice, voice cần mạng, speak hai request, stop
giữa lượt đọc, stop khi queue có phần tử, request session cũ, callback muộn,
suppression trong/ngoài cửa sổ, đổi vùng/reset session, phản hồi bị tắt. Dùng fake
clock thay sleep cho suppression. Có test fake engine và kiểm tra âm thanh thật.

**Đầu ra bàn giao:** adapter/coordinator, fake engine/clock, tests, thiết bị và
engine/voice version, phép đo stop với điểm đầu/cuối theo protocol. Mục tiêu
stop P95 trong PRD vẫn cần xác nhận; callback stop không thay bằng chứng âm thanh.

**Đạt PR:** mọi case trên có kết quả; không còn speech cũ sau stop/cancel; không
chồng hai queue; analyzer/tests pass và evidence phi cá nhân đủ để tái lập.
Nếu chưa có máy để kiểm tra voice, giữ draft theo cổng push chung.

## 6. N3-02 — OCR tiếng Việt một ảnh/yêu cầu

**Đầu vào/phụ thuộc:** G0 frame/image contract, N1 thêm package/config OCR bundled;
fixture chữ in phi cá nhân và transcription ground truth có dấu.

**Phải thực hiện:**

1. Chuyển ảnh G0 thành input plugin theo pixel format/stride/rotation/crop thực.
   Kiểm tra metadata, copy/giải phóng buffer theo G0; không tự suy đoán mọi ảnh là RGB.
2. Dùng Latin-script bundled model; xác minh dependency native, không chỉ ghi
   tên package và mặc định đã offline.
3. Mỗi request trả text theo thứ tự đọc hoặc typed empty/error; loại kết quả
   request đã hủy/session cũ. Không bịa confidence nếu plugin không cung cấp.
4. Release recognizer theo ownership G0; không đóng recognizer shared sau từng
   frame nếu chưa có quy ước. Không ghi text/ảnh vào log/cache/file.
5. Adapter không phát âm thanh: N1 quyết định hiển thị và gửi một speech request.

**Test bắt buộc:** tiếng Việt có dấu, nhãn/đoạn văn, empty/no-text, góc xoay,
metadata không hỗ trợ, ảnh mờ/lệch trong tập challenge, plugin failure, cancel
trước khi kết thúc, dispose. Test adapter bằng fake plugin boundary; test ảnh
thực và airplane mode là phần evidence riêng.

**Đầu ra bàn giao:** source/repository/use case phù hợp, fixture manifest,
ground-truth rules, tests và báo cáo CER clear/challenge theo protocol. Không
commit ảnh riêng tư hoặc đầu ra OCR có dữ liệu cá nhân.

**Đạt PR:** luồng OCR chạy cục bộ và có kết quả cho từng case; đọc lại cùng text
không tạo hai lượt speak; số đo CER có mẫu số và version. CER pilot chưa đạt
không được ghi thành nghiệm thu, ghi hạn chế/blocker để xử lý theo PRD.

## 7. N3-03 — Lệnh ngắn và persistence settings

**Đầu vào/phụ thuộc:** N3-01; G0 action/object/settings types; N1 đã thêm dependency
và cấu hình microphone/persistence. UI touch không phụ thuộc STT thành công.

**Phải thực hiện:**

1. STT chỉ start khi được N1 yêu cầu; trả khả năng nhận tiếng Việt/offline và
   failure rõ. Không mở session liên tục hoặc tự bật cloud nếu offline thiếu.
2. Parser chuẩn hóa khoảng trắng/chữ hoa-thường rồi ánh xạ các câu/alias đã thống
   nhất: Nhận diện đồ vật, Tìm [vật hỗ trợ], Đọc văn bản, Dừng đọc. Phân biệt
   không hiểu với yêu cầu tìm class chưa hỗ trợ; không fuzzy-match tùy ý gây tìm sai.
3. Dừng/đóng STT khi hết lượt, cancel, đổi session hoặc dispose; coordinator với
   N1 phải tránh engine nhận giọng của ứng dụng khi TTS đang phát.
4. Implement load/save settings PRD: speech rate, bật/tắt phản hồi và suppression;
   default, giới hạn hợp lệ và schema được chốt G0. Persist cục bộ bằng lựa chọn
   PRD; không thêm SQLite/history khi chưa có yêu cầu.
5. Báo load/save failure có kiểu; không báo lưu thành công trước khi store hoàn
   tất. Không persist OCR, transcript, camera data hay recognized-object history.

**Test bắt buộc:** đủ các lệnh/alias, khoảng trắng/case, câu rỗng, unsupported
object, STT không hỗ trợ tiếng Việt/offline, denied microphone, timeout/cancel,
command session cũ; settings chưa có key, giá trị lỗi, write failure, restart/load.
Thử voice-stop với TTS/TalkBack thực, không chỉ unit test parser chuỗi.

**Đầu ra bàn giao:** STT adapter/parser, settings implementation, fake store,
tests và bảng capability theo máy. N1 nhận typed events/settings để làm UI.

**Đạt PR:** lệnh gọi đúng action hoặc trả lỗi rõ; unsupported không giả thành
thành công; thiếu offline STT vẫn cho N1 dùng touch; settings khôi phục được sau
restart. Không cam kết STT ngoại tuyến trên mọi Android chỉ từ một máy thử.

## 8. N3-04 — Đánh giá trên build tích hợp

**Đầu vào/phụ thuộc:** N1-04 đã merge; N1 cung cấp APK/checksum và cấu hình chung.
N3 không tự đo build riêng rồi gắn kết quả cho APK tích hợp khác.

1. Khóa bộ OCR clear/challenge, ground truth, quy tắc Unicode/whitespace/CER;
   tách label/paragraph/no-text và giữ các ca lỗi/time-out trong báo cáo.
2. Đo OCR tới hiển thị, OCR tới âm thanh, touch stop và voice command/voice stop
   riêng; warm/cold riêng. Số trial, P95 nearest-rank và endpoint theo protocol.
3. Kiểm tra lời đọc có dấu/số/thứ tự, queue/suppression, missing voice/STT,
   airplane mode, TTS/TalkBack overlap và restore settings sau restart.
4. Ghi actual device/Android/engine/resource versions, sample count, kết quả,
   thiếu coverage và method giới hạn. Không bỏ ca chậm/sai để làm đẹp latency.
5. Bàn giao số liệu phi cá nhân và danh sách defect cho N1; sửa lỗi N3 sở hữu rồi
   chạy lại phần ảnh hưởng. Hỗ trợ tác vụ đọc/dừng trong pilot người dùng; N1 tổ
   chức và tổng hợp, không tạo quy trình consent hay ngưỡng riêng cạnh tranh.

**Đạt PR:** người khác tái lập được test; pass/fail/not-evaluated có bằng chứng;
ngưỡng CER/latency/cỡ mẫu chưa chốt được ghi cần xác nhận. Báo cáo này không tự
đóng N1-05 hay chứng minh toàn bộ MVP đạt nghiệm thu.

## 9. Gói bàn giao, chạy kiểm tra và yêu cầu PR

Mỗi task gửi N1: task ID/commit, implementation và fake, danh sách contract đã
tiêu thụ, dependency/config/ARB requests, failure/events, test commands/results,
device evidence, privacy check và vấn đề còn mở. Mô tả ai gọi stop/dispose và
what happens nếu kết quả tới sau cancel. Không gửi source patch lẫn file N1 sở hữu.

Chạy từ root cho app-code PR:

```sh
flutter analyze
flutter test
```

Sau khi các thư mục test dự kiến đã được tạo, có thể chạy focused tests:

```sh
flutter test test/features/text_reading
flutter test test/core/speech
flutter test test/features/settings
```

Các đường dẫn focused trên là kế hoạch, chưa tồn tại hiện tại; dùng đường dẫn
thật sau G0, không ghi rằng đã chạy khi chưa có file. Dependency/platform task
cần build staging theo cổng chung; N1 chịu wiring/DI registry cuối và sinh code
từ annotation. N3 không commit generated ngoài quyền sở hữu để giải quyết lỗi.
Task còn thiếu device checks giữ draft; module fake chưa tích hợp không được
mô tả là toàn luồng đã hoàn tất. N2 review PR N3, N1 merge theo kế hoạch nhóm.

## 10. Những việc phải chốt cùng N1/N2 trước code

- Chữ ký contract G0, pixel format/rotation, buffer lifetime và cancellation.
- Queue/interruption policy, suppression reset/reappearance và cách voice-stop
  hoạt động khi TTS/TalkBack đang phát; có test mô tả trước implementation.
- N1 cấp localization templates và action/object keys chính thức; N3 không
  định nghĩa object ID thứ hai hay hardcode chuỗi UI.
- Máy/voice/STT engine thực để thử; version dependency và settings defaults.
- Ngưỡng/cỡ mẫu sau pilot theo PRD, không tự đổi để coi task đạt.
