# N1 — nền tảng Android, giao diện truy cập và tích hợp

Đọc [phân công chung](team-work-plan.md) trước tài liệu này. Đây là hướng dẫn
triển khai dự kiến, không phải danh sách file/chức năng đã có. N1 không phải
người làm thay thuật toán detection, OCR hoặc speech của N2/N3.

## Kết quả cuối N1 phải giao

Một bản Android có các thao tác Nhận diện, Tìm vật, Đọc văn bản, Dừng đọc và
Cài đặt; các thao tác dùng được với TalkBack và đi qua adapter thật. Camera,
mode/session và provider có chủ sở hữu rõ; cấu hình đúng privacy; có PR checks
và báo cáo nghiệm thu. Model/speech chất lượng chưa đạt vẫn phải ghi blocker,
không đánh dấu toàn MVP hoàn thành chỉ vì màn hình đã nối được.

## Kiến thức cần tìm hiểu và cách tự kiểm tra

| Chủ đề | Cần hiểu để làm gì | Bài kiểm tra trước khi code task thật |
| --- | --- | --- |
| Dart async, stream, timer, resource ownership | Tránh callback chạy sau đổi mode, dispose hai lần, giữ camera trong nền | Dùng fake trả kết quả trễ; hủy session rồi chứng minh kết quả không đổi UI hoặc gọi speech |
| Riverpod 2 | Phân biệt dependency provider, notifier, `AsyncValue`, state local, scope và cleanup | Đọc Home; dùng `ProviderContainer` override use case và kiểm tra idle/loading/data/error |
| Clean Architecture và GetIt/Injectable | Domain không phụ thuộc plugin; GetIt cấp dependency, Riverpod giữ state | Vẽ đường Screen → Notifier → Use case → Contract → Adapter; chỉ ra nơi đăng ký adapter và cách test không cần GetIt production |
| Android camera, quyền và lifecycle | Đúng format/rotation/crop, ownership buffer, grant/deny/revoke/background | Camera spike trên máy thật; denial không crash; background ngừng tài nguyên; resume không mở hai session |
| Accessibility và localization | TalkBack label/focus, semantics, 48dp, text scaling, tránh TTS chồng TalkBack | Điều khiển UI fake chỉ bằng TalkBack; dừng đọc tới được khi text scale lớn |
| Git/CI và sinh code | Đúng nhánh/PR, dependencies, lockfile, generated registration, test gate | PR thử có analyze/test/build; kiểm tra lỗi test làm check fail; generator không ghi đè file source |
| Đánh giá và privacy | Phân biệt kết quả đo với target; không thu ảnh/âm thanh làm log debug | Lập một record synthetic theo protocol có device/commit/denominator; kiểm tra log không có payload |

Đọc theo thứ tự: [quick start](quick-start-guide.md), [code standards](code-standards.md),
[architecture](system-architecture.md), [PRD](../tasks/prd-seemate-ai.md),
[protocol](evaluation-protocol.md). Mã tham chiếu hiện có:
[Home providers](../lib/features/home/presentation/home_providers.dart),
[Home screen](../lib/features/home/presentation/home_screen.dart),
[bootstrap](../lib/app.dart), [DI](../lib/core/di/get_it.dart),
[router](../lib/core/router/router.dart),
[permission wrapper](../lib/core/permissions/permission_view_model.dart),
[provider tests](../test/features/home/home_providers_test.dart),
[widget test](../test/widget_test.dart), [CI](../.github/workflows/dart.yml).
Đọc lifecycle API/package được chọn trong G0 trước khi dùng; không copy API của
Riverpod phiên bản khác hoặc mặc định permission wrapper đã xử lý camera.

## Phạm vi chức năng phải code

1. **Shell và state:** màn hình mode, chọn vật muốn tìm, trạng thái chuẩn bị/
   đang chạy/không có kết quả/lỗi, vùng kết quả và settings. Mode là hành động
   đang chọn; loading/error là trạng thái thực thi, không tạo thêm mode tùy tiện.
2. **Camera:** kiểm tra quyền, mở preview/session, phát frame có metadata, lấy
   ảnh cho OCR, tạm dừng/đóng; giới hạn frame đang xử lý theo contract.
3. **Orchestration:** một mode/session đang hoạt động; gọi N2 khi detection/search,
   gọi N3 khi OCR; chỉ chuyển kết quả còn hợp lệ tới speech coordinator N3.
4. **Touch/voice bridge:** nút cảm ứng và command event N3 đi vào cùng một đường
   xử lý action. Lệnh tìm vật chỉ dùng object key đã chốt; unsupported phải được báo.
5. **Dừng:** gọi stop của N3, hủy request đọc đang chờ để kết quả trễ không tự đọc
   lại. Dừng TTS và dừng camera là hai thao tác khác nhau; chốt hành vi tại G0.
6. **Settings UI:** đọc/ghi qua contract N3; UI có loading/save failure; không tự
   tạo SharedPreferences instance hoặc lưu bản sao settings riêng.
7. **Composition/config:** dependencies, model assets, native permissions, ARB,
   DI/provider/router, telemetry-disabled MVP, PR workflow và báo cáo tích hợp.

N1 không tự preprocessing tensor, decode detection, OCR hoặc viết STT/TTS engine.
Các adapter chỉ đưa kết quả typed; việc hiển thị/dialog/navigation nằm ở widget.
Speech coordinator xử lý queue/suppression; N1 không thêm cơ chế chống lặp thứ hai.

## Các file dự kiến và trách nhiệm

Tên dưới đây là gợi ý để chốt trong G0, không phải file đang tồn tại:

| Vị trí | Nội dung |
| --- | --- |
| `lib/shared/assistance_contracts/` | Enum/value types và interface plugin-independent; fakes chia sẻ trong test thuộc N1 |
| `lib/core/camera/` | Adapter camera/permission/resource owner; chuyển frame và metadata, không xử lý model |
| `lib/features/assistance/domain/` | Use case điều phối mode/session và kiểm tra kết quả hợp lệ |
| `lib/features/assistance/presentation/` | Providers/notifier, screen, controls, preview, kết quả/feedback accessibility |
| `lib/features/settings/presentation/` | Screen/provider settings dùng repository contract N3 |
| `test/core/camera/`, `test/shared/assistance_contracts/`, `test/features/assistance/` | Fake/unit/widget tests thuộc N1 |
| `test/features/settings/presentation/`, `test/widget_test.dart`, `integration_test/` | Settings UI, router và full-flow integration tests thuộc N1 |

File bootstrap/router/DI/ARB/native/pubspec/lockfile/workflow giữ đúng ownership
trong kế hoạch chung. Đổi package/app ID là việc riêng, chưa được giao ở đây.

## G0 — những quyết định phải giao trước cho N2/N3

- Chữ ký Dart cụ thể cho frame, detection, OCR, speech, command và preferences.
  Chọn error/result type rõ; không để mỗi người định nghĩa object key riêng.
- Frame coordinates: đơn vị, vùng nhìn sau rotation/crop, buffer có copy hay mượn,
  thời điểm trả quyền buffer, tối đa request đang chạy và cách drop frame cũ.
- Session/request ID; ai gọi start/stop/dispose; thao tác nào idempotent; tài nguyên
  nào dùng chung, tài nguyên nào thuộc một request; callback muộn xử lý thế nào.
- Lớp detection result ổn định từ N2; speech request từ N1 sang N3, ưu tiên stop,
  invalidation khi đổi mode và suppression key/zone change/reappearance.
- Settings default/type, STT action → mode, ARB key cho prompt chung; mỗi adapter
  trả error code thay vì hardcode câu tiếng Việt hoặc gọi widget.
- Danh sách dependency/model asset/native config N2/N3 yêu cầu và fake cho mỗi
  contract. Chỉ commit API/fake cần cho task đầu tiên, tránh xây framework lớn.

**Bằng chứng G0:** test consumer dùng fake của các contract chạy được; N2/N3
review API và xác nhận có thể bắt đầu. Đây mới là hợp đồng code cuối cùng;
tên hoặc ý tưởng trong tài liệu không thay thế PR contract được merge.

## N1-01 — camera và permission/session

**Đầu vào:** G0, package/config đã chốt và điện thoại có camera. **Đầu ra:** camera
adapter và unit tests, ghi nhận check thật theo model máy/Android.

Các bước:

1. Dùng wrapper permission hiện có, bổ sung native configuration đúng package;
   phân biệt denied, permanentlyDenied, revoked và camera unavailable.
2. Mở session khi được phép; phát preview và frame/ảnh theo contract, không lưu
   file tạm chứa camera frame nếu chưa có thiết kế phù hợp chính sách PRD.
3. Chặn request chồng lấn, trả buffer đúng vòng đời; lỗi adapter trả typed failure.
4. Background/đổi mode/permission revoke: vô hiệu session trước, dừng stream và
   đóng/tạm dừng theo contract; resume kiểm tra lại quyền và readiness.

**Test bắt buộc:** denied không mở camera; request hai lần không có hai owner;
release sau lỗi; dispose nhiều lần an toàn; frame cũ bị drop; callback session cũ
bị bỏ qua. Trên máy thật kiểm tra deny/allow/settings/revoke/background/resume.
**Đạt:** tests pass, camera chạy lại được sau resume và không có frame trong log/cache.

**Hiện trạng local:** màn hỗ trợ mở preview camera sau qua Flutter CameraX
khi người dùng chọn chế độ. Khi màn bị che hoặc app ra nền, phiên camera đóng.
Khi quay lại, app kiểm tra quyền trước khi mở lại. Driver có thể cung cấp frame
YUV420 trong RAM, gồm stride và góc xoay. Phiên chỉ bật phân tích ảnh khi có
consumer. Bước tích hợp detector và chụp một frame cho OCR còn lại ở N1-04.
[Flutter camera](https://pub.dev/packages/camera) · [Góc xoay CameraX](https://developer.android.com/media/camera/camerax/orientation-rotation#image-rotation)

**Kiểm tra ngày 2026-11-09:** APK staging khởi động trên Realme 5i
(`RMX2032`, Android 10). Màn hỗ trợ báo preview sẵn sàng. Android camera
service xác nhận camera 0 mở, đóng khi bấm Home và mở lại khi quay về app.
Luồng từ chối và thu hồi quyền đã qua widget test. Kiểm tra hai tình huống đó,
xoay máy và TalkBack trên điện thoại vẫn còn mở.

## N1-02 — giao diện truy cập, dùng fake trước

**Đầu vào:** G0/fake; chưa cần N2/N3 adapter thật. **Đầu ra:** UI và widget tests.

- Tạo các control nhận diện, tìm vật, đọc văn bản, dừng đọc và settings; màn hình
  chọn vật chỉ đưa danh mục hỗ trợ, không biến nhãn COCO thành lời hứa tính năng.
- Render idle/loading/data/empty/error/resource-missing riêng; localized prompt
  hướng dẫn người dùng thay vì raw exception. Fake cover đủ trạng thái.
- N1 hiển thị hướng dẫn tiếng Việt khi nhận diện thiếu tin cậy hoặc ảnh OCR
  không đọc được (FR-11). Trong onboarding và màn kết quả liên quan, nêu phạm
  vi hỗ trợ quan sát và giới hạn về dẫn đường, tránh vật cản (FR-15).
- TalkBack focus theo thứ tự task; không để preview tranh focus với control.
  Vùng chạm, text scaling, nội dung dài, back và Stop phải hoạt động.
- Settings UI dùng fake repository N3, chứng minh thay đổi/restore/save failure.

**Đạt:** widget/semantics/accessibility guideline tests pass, thao tác bằng TalkBack
không phụ thuộc nhìn preview; có checklist kiểm tra thật. Không gọi UI fake là AI chạy được.

## N1-03 — cấu hình MVP và CI

**Đầu vào:** dependency/config request từ N2/N3. **Đầu ra:** manifest/pubspec/assets,
bootstrap và workflow đúng trạng thái mới.

- Thêm dependency đã kiểm tra tương thích, pin qua lockfile; khai báo model asset
  do N2 giao; OCR bundled config do N3 giao. Không tự đổi adapter của họ.
- Ngăn 5 dịch vụ telemetry trong PRD được khởi tạo/thu thập ở cấu hình MVP,
  giữ cache/DI cần thiết hoạt động. Kiểm tra lỗi Firebase absent vẫn khởi động được.
- Thêm trigger pull request và bước test thực thi; giữ analysis/staging build;
  chứng minh một PR lỗi test bị chặn ở check. Required checks trên hosting chỉ
  được ghi đã bật khi có quyền và đã kiểm chứng; giữ debug signing đúng mô tả.

**Đạt:** analyze/test/build pass; có audit đường bootstrap và check network khi
các luồng đã tích hợp. Trước tích hợp chỉ kết luận cấu hình được kiểm tra, chưa
được nhận rằng mọi flow đã offline. Không commit khóa ký hoặc secrets.

## N1-04 — tích hợp các adapter thật

**Đầu vào:** các PR phụ thuộc trong bảng task chung đã merge. **Đầu ra:** wiring
GetIt/provider, route thật và integration tests; build/checksum dùng chung để đo.

1. Nhận manifest/API readiness từ N2/N3; đăng ký adapter trong DI, sinh registration.
2. Nối action touch và voice vào notifier; nối camera tới đúng adapter theo mode.
3. Nối kết quả N2/OCR vào state và speech coordinator; load settings từ N3 và
   áp dụng cho speech; hủy session cũ trước chuyển mode; stop hủy đọc đang chờ.
4. Chạy một walkthrough: tìm chai → chuyển OCR → dừng lúc đang đọc → vào nền →
   quay lại → thiếu offline STT vẫn dùng control. Không có stale speech/frame.

**Đạt:** integration test fake chạy deterministic; full-flow check thật được ghi
theo thiết bị, có TTS/TalkBack overlap và trạng thái thiếu tài nguyên. Nhánh tích
hợp baseline có thể review nhưng toàn bộ model coverage vẫn phải ghi chưa đạt.

## N1-05 — nghiệm thu và đóng mốc

**Đầu vào:** N2/N3 giao báo cáo cùng APK/checksum và cấu hình đã khóa. **Đầu ra:**
báo cáo hợp nhất theo protocol, defect list và trạng thái roadmap có bằng chứng.

- N1 đo network/lifecycle/continuous session, điều phối người thử và consent;
  N2 chuẩn bị cảnh tìm vật, N3 chuẩn bị nhãn/đoạn văn và stop; chỉ N1 ghi kết quả chung.
- Thử airplane mode và connectivity enabled audit; nguồn cài voice/model ghi riêng;
  không nhầm không truyền được mạng với không có request bị thử gửi.
- Pilot rồi sửa lỗi, chốt threshold/sample/task limit trước confirmation; không
  tự biến cỡ mẫu hoặc target đề xuất thành số liệu đã đo. Người dùng/proxy báo riêng.
- Đóng milestone khi đúng exit criteria; thiếu class/thiết bị/ngưỡng/xác nhận thì
  ghi blocker. P0/P1 hoặc task sai/miss/time-out không được xóa khỏi báo cáo.

## Bàn giao, review và nhịp làm việc

Mỗi PR N1 gửi cho N3 review, G0/API chung cần cả N2/N3. Khi N2/N3 thiếu config,
N1 ưu tiên PR cấu hình nhỏ và trả commit nền để họ tiếp tục, không đợi UI hoàn tất.
Cuối mỗi vòng tích hợp công bố commit, adapter versions, known blockers và APK
checksum. Chỉ review/merge theo [cổng chung](team-work-plan.md#cổng-push-review-và-merge).
Nếu N1 quá tải, ba người thay bảng ownership bằng PR rõ ràng trước khi chuyển việc.

Lệnh hiện có, chạy từ root, áp dụng khi code thay đổi:

```sh
flutter analyze
flutter test
flutter build apk --release -t lib/main_staging.dart
```

Các đường dẫn test mới ở trên chưa tồn tại; chỉ thêm focused-test command sau
khi tạo file, không coi ví dụ đường dẫn là test đã được chạy. PR phải đính kèm
commit/test output và checklist thiết bị; điều kiện push khác nhau với WIP/draft
và ready-for-review như kế hoạch chung.
