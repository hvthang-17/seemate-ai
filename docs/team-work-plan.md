# Kế hoạch triển khai cho nhóm 3 người

Đây là phân công đề xuất theo vai trò N1/N2/N3, chưa phải công việc đã hoàn
thành. Nhóm gán tên thật trước khi bắt đầu. Phạm vi theo [PRD](../tasks/prd-seemate-ai.md),
thứ tự theo [roadmap](development-roadmap.md), đo theo [evaluation protocol](evaluation-protocol.md).
Không ấn định ngày khi chưa biết thời gian mỗi người có thể dành cho dự án.

## Cách dùng bộ hướng dẫn giao việc

Đây là kế hoạch chung về ownership, phụ thuộc và push/merge. Mỗi thành viên đọc
thêm hướng dẫn theo vai trò để biết kiến thức cần học, chức năng cần code, bước
thực hiện, test và bằng chứng bàn giao:

- [N1 — nền tảng, UI và tích hợp](team-member-01-platform.md).
- [N2 — model, detection và tìm vật](team-member-02-detection.md).
- [N3 — OCR, speech và cài đặt](team-member-03-ocr-speech.md).

Nếu bài tự kiểm tra kiến thức chưa làm được, ghi phần cần hỗ trợ trước khi nhận
task phụ thuộc kiến thức đó. Chốt API bằng PR G0; các tên file/class minh họa
trong hướng dẫn chưa phải code đã tồn tại hoặc hợp đồng được tự ý thay đổi.

### Việc đầu tiên mỗi người cần giao

| Người | Sau khi đọc tài liệu, phải giao gì trước khi triển khai adapter |
| --- | --- |
| N1 | Bản API G0, fake cho consumer, quy tắc session/buffer/cancellation, danh sách file chung cần cấu hình; PR cho hai người còn lại review |
| N2 | Bảng 19 object key ↔ nhãn thực của baseline, lớp thiếu và phương án dữ liệu; định dạng tensor/frame cần từ camera; model artifact/source/license và yêu cầu dependency/assets gửi N1 |
| N3 | Kết quả khảo sát OCR bundled và vi-VN TTS/STT theo máy; contract speech/stop/settings cần dùng; dependency/native/ARB key request gửi N1 |

Các khảo sát là deliverable tài liệu/feasibility, chưa phải task tính năng đã đạt.
N2/N3 có thể chuẩn bị dữ liệu và thử API qua fake trong lúc chờ cấu hình; không
tự sửa pubspec/native/shared contract để tránh thời gian chờ.

## Quyền sở hữu file

Các thư mục mới bên dưới là vị trí dự kiến, chưa tồn tại trong code hiện tại.
Test và tài liệu kết quả đi theo cùng chủ sở hữu.

| Người | Trách nhiệm và quyền sửa độc quyền |
| --- | --- |
| N1 — nền tảng, UI, tích hợp | `lib/features/assistance/`, `lib/shared/assistance_contracts/`, `lib/core/camera/`, `lib/features/settings/presentation/`, `lib/app.dart`, entry points, `lib/core/router/`, `lib/core/di/`, `lib/core/permissions/`, `lib/core/firebase/`, `lib/core/analytics/`, `lib/shared/i18n/`, `android/`, `pubspec.yaml`, `pubspec.lock`, `.github/workflows/`; test tương ứng và `integration_test/` |
| N2 — detection, vị trí, tìm vật | `lib/features/object_detection/`, `assets/models/object_detection/`, `tool/model_evaluation/`, `test/features/object_detection/`, `docs/evaluation/object_detection/` |
| N3 — OCR, giọng nói, cài đặt | `lib/features/text_reading/`, `lib/core/speech/`, `lib/features/settings/data/`, `lib/features/settings/domain/`, test tương ứng, `docs/evaluation/text_speech/` |

N1 giữ `README.md`, index docs, roadmap, PRD/PDR, protocol và báo cáo tích hợp.
N2/N3 gửi yêu cầu thay đổi các file chung bằng danh sách dependency, cấu hình,
ARB key hoặc contract cần thêm; N1 thực hiện trong PR riêng trước PR phụ thuộc.
File ngoài bảng giữ nguyên cho đến khi nhóm ghi rõ chủ sở hữu mới tại đây.
Không tự sửa file người khác để vượt lỗi tích hợp. Không đưa media cá nhân,
dataset lớn hoặc dữ liệu người tham gia vào Git; thư mục kết quả chỉ lưu số liệu
phi cá nhân và manifest/nguồn dữ liệu được phép công khai.

N1 thực hiện lần sinh DI chung cuối cùng sau khi hợp nhất các source annotation.
N2/N3 được chạy generator để kiểm tra cục bộ nhưng không commit thay đổi generated
ngoài phạm vi mình sở hữu. Mọi file generated đều phải sinh từ source, không sửa tay.
PR module có thể được review bằng contract/fake trước khi nối production DI;
phải ghi rõ trạng thái đó. N1 thực hiện registration/generation trong PR tích
hợp sau module, rồi kiểm tra build thật. Nếu generator bắt buộc tạo thay đổi file
chung để module compile, N1 phối hợp đưa file sinh vào chính PR đó và duyệt diff;
không để tác giả tự sửa generated hoặc merge code không compile.

Để phân biệt test ownership: N1 giữ `test/core/camera/`,
`test/core/permissions/`, `test/shared/assistance_contracts/`,
`test/features/assistance/`, `test/features/settings/presentation/`,
`test/widget_test.dart` và `integration_test/`; N2 giữ
`test/features/object_detection/`; N3 giữ `test/core/speech/`,
`test/features/text_reading/`, `test/features/settings/data/` và
`test/features/settings/domain/`. Những path mới là kế hoạch sẽ tạo.

### Mẫu yêu cầu sửa file chung

N2/N3 gửi N1: task ID; file cần sửa; dependency/version constraint và lý do;
model asset hoặc native requirement; ARB key + nội dung tiếng Việt; contract
thay đổi nếu có; test/check chứng minh cấu hình đúng; task nào đang chờ.
N1 trả PR/commit cấu hình đã merge hoặc blocker cụ thể. Hai người không đồng
thời tự cập nhật lockfile, ARB hay registry trên nhánh khác nhau.

## Cổng G0 — chốt hợp đồng trước khi làm song song

N1 tạo PR `G0-contracts`; N2 và N3 cùng review, sau đó merge trước các task khác.
Đặt các interface/value type dùng chung tại `lib/shared/assistance_contracts/`,
không import plugin camera/ML Kit/LiteRT vào các contract. Đây là thư mục tập hợp
contract domain dùng chung, không phải lớp service locator hay nơi chứa implementation.

| Contract cần định nghĩa trong G0 | Nội dung bắt buộc |
| --- | --- |
| Frame/session | Frame ID, session ID, timestamp, kích thước, pixel format, rotation/crop transform, quyền sở hữu buffer và thời điểm giải phóng; frame mới không bị backlog |
| Detection | Object key, bounding box trong hệ tọa độ đã thống nhất, confidence, zone, typed failure; phương thức nhận frame và đóng tài nguyên |
| OCR | Một yêu cầu/ảnh, kết quả văn bản theo thứ tự đọc, chất lượng/empty/error, cancellation/session token; không lưu ảnh |
| Speech | Kiểm tra giọng offline, speak/stop/cancel, sự kiện trạng thái; chỉ một speech coordinator sở hữu playback |
| Command | Enum hành động và object key, không hiểu lệnh/không hỗ trợ; STT session có start/stop/dispose |
| Preferences | Tốc độ đọc, bật/tắt phản hồi, cấu hình chống lặp; load/save, default và typed failure |

G0 phải có chữ ký Dart cụ thể, quy tắc đồng thời/cancellation, kết quả khi dispose,
và fake implementation dùng được trong test. N1 sở hữu mode/session state và
quyết định kết quả nào được đọc; N2 sở hữu confidence/stability/zone/target matching;
N3 sở hữu TTS queue, STT, lưu settings và suppression của speech coordinator.
Suppression chỉ có một implementation tại N3, khóa theo object key + zone;
quy tắc đổi vùng/reappearance được chốt và test trong G0, không nhân đôi ở N2.
N1 chuyển preferences vào coordinator; N2 không gọi TTS trực tiếp.

**Đạt G0:** cả ba thống nhất API, có test contract/fake, analyzer/test pass,
N2/N3 có thể bắt đầu mà không cần sửa file N1. Dependency và ARB key đầu tiên
được N1 thêm cùng G0 hoặc PR cấu hình nối tiếp. Thay đổi API sau đó phải có PR
contract của N1 và review của người tiêu thụ trước khi sửa implementation.

## Task và điều kiện được đưa lên PR

Mỗi hàng là một PR nhỏ riêng; dùng task ID làm nhánh và tên PR. Các điều kiện
dưới đây bổ sung cho cổng push chung ở cuối tài liệu.

| ID / người | Phụ thuộc | Đầu ra | Đạt khi |
| --- | --- | --- | --- |
| N1-01 | G0 | Camera adapter và vòng đời quyền/session | Chỉ mở sau cấp quyền; denial/permanent denial/revocation có trạng thái rõ; background/đổi mode/dispose đóng đúng; không backlog, không nhận kết quả session cũ; test fake và kiểm tra điện thoại thật |
| N1-02 | G0 | Home hỗ trợ, controls tiếng Việt, settings UI dùng fake | Đủ nhận diện/tìm/đọc/dừng; TalkBack label/focus, vùng chạm 48dp, text scaling; Stop luôn tới được; widget/accessibility test pass |
| N1-03 | G0 | Cấu hình MVP và CI | Tắt 5 dịch vụ telemetry trong PRD; kiểm tra đường khởi tạo và không phá bootstrap; bật `flutter test` trong CI; analyzer, tests, staging APK build thành công; ghi trigger thực tế, không nhận debug signing là production release |
| N2-01 | G0, dependency PR | Baseline detection adapter, model manifest | Model chạy cục bộ trên điện thoại; checksum/source/license/labels có; input transform đúng contract; fake/unit test tensor-result mapping và typed failures; liệt kê đủ lớp có/thiếu; baseline chưa đủ lớp không ghi đạt MVP |
| N2-02 | N2-01 | Confidence, stability, zone, target search | Test đúng/sai class, target vắng/không hỗ trợ, nhiều vật, biên vùng/rotation; chỉ trả kết quả đủ điều kiện; không phát speech, không tự lưu frame |
| N2-03 | N2-02 | Model cuối và báo cáo detection độc lập | Bao phủ đủ 19 lớp hoặc báo blocker; không tự bỏ Wallet/Keys/Bread; test set khóa độc lập; TP/FP/FN, precision/recall từng lớp, negative scenes, zone accuracy có mẫu số; ngưỡng chưa chốt ghi cần xác nhận |
| N3-01 | G0, dependency PR | Offline TTS coordinator và stop | Check giọng vi-VN không cần mạng; thiếu tài nguyên có typed result; queue không chồng tiếng; stop/cancel không phát lại kết quả cũ; suppression một chỗ có test fake-clock; chạy được trên máy thật, có ghi đo stop |
| N3-02 | G0, dependency PR | OCR adapter một ảnh/yêu cầu | Bundled Latin ML Kit; chữ có dấu/empty/failure/cancel được test; chạy airplane mode; báo CER theo protocol, tách clear/challenge; không log OCR/ảnh, không tự đọc kết quả ngoài coordinator |
| N3-03 | N3-01 | Lệnh ngắn và settings repository | Parser đủ lệnh PRD + unsupported target; STT chủ động, không tự cloud fallback; settings khôi phục sau restart; test parser/storage/default/cancellation; thiếu offline STT vẫn trả trạng thái để UI dùng touch |
| N1-04 | N1-01/02/03, N2-02, N3-01/02/03 đã merge | Wiring thật qua GetIt/provider và kiểm thử tích hợp | Nhận diện/tìm/đọc/dừng và settings đi xuyên các adapter thật; sai mode/session bị loại; không tồn tại hai camera owner hoặc hai TTS owner; TalkBack/TTS/STT overlap, thiếu quyền/model/voice, background/resume được kiểm tra |
| N2-04 | N1-04 | Chạy bộ cảnh detection trên build tích hợp | N2 chịu dataset/annotation và kết quả detection/zone/search; report theo device/scene, failures/time-outs; không coi benchmark riêng adapter thay nghiệm thu toàn luồng |
| N3-04 | N1-04 | Chạy bộ cảnh OCR/voice trên build tích hợp | N3 chịu transcription/CER, speech intelligibility, stop, STT fallback và settings; report riêng warm/cold, máy/engine và lỗi |
| N1-05 | N2-03/04, N3-04, N1-04 | Nghiệm thu chung | N1 chạy network/lifecycle/session15phút và tổ chức pilot5–8 + confirmation; N2 kiểm tra ground truth/task tìm vật, N3 kiểm tra nội dung đọc/stop; N1 tổng hợp số liệu, device gaps, P0/P1, cập nhật roadmap chỉ khi đủ bằng chứng |

Task N2-03 có thể kéo dài song song N3-01/02/03 và tích hợp baseline; thiếu model
cuối không chặn demo kỹ thuật nhưng chặn đánh dấu hoàn thành recognition MVP.
Trong hàng N2-03, báo blocker là cách báo tiến độ chưa đạt, không phải điều kiện
thay thế cho bao phủ 19 lớp. Code cải thiện một phần có thể merge khi đạt gate
code của PR và được ghi rõ partial; task/model acceptance vẫn để chưa hoàn thành.
N1-05 chỉ đạt khi tiêu chí PRD đã được đo và đáp ứng; thiếu máy, mẫu hay ngưỡng
được xác nhận phải ghi chưa đánh giá/blocker, không được coi là pass.

### Mẫu bàn giao một task

Mỗi task phải có cùng cấu trúc trong PR, không chỉ ghi “đã làm xong”:

1. **Mục tiêu:** task ID, US/FR trong PRD và hành vi người dùng được bổ sung.
2. **Đầu vào/phụ thuộc:** commit G0/config/module đã merge; thiết bị/tài nguyên cần có.
3. **Phạm vi:** file đã sửa, public API/typed result và phần chưa được nối vào app.
4. **Ca kiểm tra:** happy path, empty/error, permission/resource failure nếu liên quan,
   cancel/dispose/late result; expected và actual.
5. **Bằng chứng:** commit kiểm tra, lệnh/kết quả, máy/Android/engine/model checksum,
   số liệu phi cá nhân và nơi lưu report được phép chia sẻ.
6. **Kết luận:** ready hay draft/partial; requirement nào đạt/chưa đo/chưa đạt;
   việc người nhận cần làm tiếp và blocker cụ thể.

Chạy test fake chỉ chứng minh logic/contract; chạy máy thật chứng minh adapter
trên cấu hình đó; chạy protocol mới cho bằng chứng chất lượng. Ba mức này
không thay thế nhau. Không giữ PR “ready” nếu tiêu chí bắt buộc của phần đang
xin review chưa được kiểm chứng; có thể tách phần thuần logic thành PR riêng.

## Thứ tự tích hợp

1. G0 và dependency/config PR của N1 merge trước.
2. N1-01/02/03, N2-01/02 và N3-01/02/03 triển khai song song qua fake/contract.
   N2-03 thu thập/huấn luyện và khóa dữ liệu song song.
3. N1 merge lần lượt các adapter, sinh DI từ source, rồi làm N1-04.
4. N2-04 và N3-04 đo độc lập trên cùng APK/checksum; N1 chạy phần hệ thống và
   kiểm thử người dùng. Sau sửa lỗi, đo lại phần bị ảnh hưởng trước N1-05.

## Cổng push, review và merge

Push nhánh cá nhân là lưu tiến độ; merge vào `development` mới là tích hợp.
Mặc định tên nhánh `codex/<task-id>-<short-name>`. Không push thẳng nhánh chung,
không force-push nhánh người khác. Trước khi bắt đầu, nhóm thống nhất commit nền
vì checkout hiện có nhiều thay đổi docs chưa commit; không gộp chúng vào task app.

**Push WIP:** chỉ lên nhánh riêng và đánh dấu draft/WIP; mô tả thiếu gì, test nào
chưa chạy. Không đánh dấu task hoàn thành, không để PR WIP được hiểu là đạt cổng merge.

**Push PR sẵn review:**

- Chỉ có file thuộc quyền sở hữu, task ID và yêu cầu PRD liên quan; dùng diff
  để kiểm tra không kèm secrets, media, generated ngoài scope hoặc đổi identity.
- Rebase/merge từ `development` mới nhất và giải quyết xung đột trên nhánh riêng.
- Với code: `flutter analyze` và `flutter test` pass trên commit được push;
  test mới bao phủ hành vi/lỗi/cancellation của task. DI/model annotation thay
  đổi phải regenerate; ARB đổi phải gen-l10n. Không sửa generated tay.
- Platform/dependency/config và N1-04/05 phải build
  `flutter build apk --release -t lib/main_staging.dart` thành công. Các task
  platform/AI/speech kèm thiết bị, phiên bản, bước chạy và kết quả check thật
  nêu trong hàng task. Chưa có máy/bằng chứng thì giữ draft.
- PR ghi đầu ra, test command/kết quả, commit kiểm tra, bằng chứng phi cá nhân,
  giới hạn và dependency PR đã merge. Docs-only kiểm tra link/fact/command,
  không cần chạy lại Flutter nếu không đổi code.

**Review:** N1 review N2; N2 review N3; N3 review N1. G0 và thay đổi API dùng chung
cần cả hai người còn lại review. Người tạo PR không tự duyệt PR của mình.
Reviewer kiểm tra đúng scope, contract, privacy và bằng chứng đạt task.

**Merge:** N1 là đầu mối merge sau approval của reviewer và checks bắt buộc pass.
Trước khi N1-03 bật tests, đính kèm test local vì CI hiện chưa chạy test; CI hiện
chỉ push `development`/tag `v1.*`, chưa có trigger PR. N1-03 phải thêm PR trigger
và kiểm tra analyze/test/build trên PR; cấu hình required checks trong Git hosting
cần quyền quản trị, nếu thiếu quyền phải ghi rõ và áp dụng review/check thủ công.
Không tự tuyên bố branch protection đã bật. Sau merge lỗi thuộc module nào,
owner module đó sửa; N1 chỉ sửa wiring/config thuộc mình.

## Điểm cần nhóm xác nhận trước G0

- Tên thật cho N1/N2/N3, người có quyền merge/thiết lập required checks.
- Điện thoại nào nhóm có thể dùng cho ba profile và thời gian mỗi người tham gia.
- Thời lượng thực tế cho model/data và tuyển người kiểm thử; không tự hạ phạm vi
  hoặc ngưỡng để khớp lịch. Chốt mốc lịch sau kết quả feasibility đầu tiên.
