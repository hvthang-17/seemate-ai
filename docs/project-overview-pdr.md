# Yêu cầu phát triển dự án: SeeMate AI

## Sản phẩm

SeeMate AI là ứng dụng Android hỗ trợ người khiếm thị và người có thị lực suy giảm nhận biết môi trường qua camera điện thoại và phản hồi giọng nói. Ứng dụng giúp người dùng chủ động hơn khi tìm vật dụng, đọc chữ trên giấy tờ hoặc nhãn sản phẩm, và biết vị trí tương đối của một vật trong khung hình.

MVP tập trung vào ba luồng hỗ trợ: nhận diện đồ vật, đọc văn bản bằng OCR, và thông báo vị trí trái/giữa/phải. Các chức năng nhận diện cốt lõi được định hướng chạy trên thiết bị sau khi đã có mô hình và dữ liệu ngôn ngữ cần thiết; ảnh camera không được gửi lên máy chủ trong các luồng MVP.

Tài liệu này là nguồn chuẩn cho tổng quan sản phẩm: vấn đề, người dùng mục tiêu, phạm vi MVP và giới hạn. [PRD SeeMate AI](../tasks/prd-seemate-ai.md) là nguồn chuẩn cho user story, yêu cầu chi tiết, tiêu chí nghiệm thu và chỉ số đánh giá; các mục tương ứng bên dưới chỉ là bản tóm tắt. Khi thay đổi phạm vi hoặc yêu cầu, phải cập nhật hai tài liệu cùng nhau và giải quyết rõ mọi mâu thuẫn trước khi triển khai phần bị ảnh hưởng.

## Trạng thái và cách đọc

Dự án đang ở giai đoạn xây nền từ Flutter Agentic Starter. Home hiện là ví dụ tải danh sách thành phố; các luồng camera, nhận diện đồ vật, OCR và điều khiển/phản hồi giọng nói của MVP chưa được triển khai. Yêu cầu trong tài liệu này mô tả sản phẩm mục tiêu. Hiện trạng mã nguồn được ghi tại [Codebase summary](codebase-summary.md#implementation-status).

Các lựa chọn và bằng chứng kỹ thuật còn thiếu được theo dõi tập trung trong [sổ quyết định chưa chốt của PRD](../tasks/prd-seemate-ai.md#96-open-decisions-and-validation-gaps). Danh sách lớp đồ vật, cấu hình thử nghiệm và thiết bị mục tiêu bên dưới cần được xác nhận bằng mô hình, dữ liệu và benchmark thực tế.

## Vấn đề và người dùng mục tiêu

Người khiếm thị, người có thị lực suy giảm và một số người cao tuổi thường khó tự tìm vật dụng, đọc thông tin in hoặc xác định vật thể đang nằm về phía nào. Việc phải nhờ người khác cho các tác vụ này làm giảm tính chủ động trong sinh hoạt hằng ngày.

SeeMate AI phục vụ chủ yếu người dùng nói tiếng Việt. Trải nghiệm phải ưu tiên thao tác không cần nhìn màn hình, nhưng vẫn hiển thị kết quả trực quan cho người dùng có thị lực suy giảm và người kiểm thử.

## Mục tiêu MVP

- Cho phép kích hoạt nhận diện đồ vật, tìm đồ vật, đọc văn bản, chụp ảnh trong chế độ đọc, dừng đọc và trở về màn hình chọn chế độ bằng lệnh nói tiếng Việt hoặc điều khiển cảm ứng có thể truy cập.
- Nhận diện các lớp đồ vật được mô hình hỗ trợ, lọc kết quả không đủ tin cậy, rồi đọc tên và vị trí trái/giữa/phải.
- Trích xuất văn bản tiếng Việt từ camera bằng OCR và đọc nội dung bằng Text-to-Speech.
- Cho phép object detection và OCR hoạt động khi mất mạng nếu mô hình, gói OCR và dữ liệu giọng nói cần thiết đã được cài đặt.
- Hạn chế thông báo lặp và đưa hướng dẫn điều chỉnh camera khi hình ảnh không đủ chất lượng.
- Kiểm thử các luồng cốt lõi với người dùng mục tiêu hoặc quy trình đánh giá accessibility tương đương.

## Phạm vi chức năng

1. **Điều khiển và accessibility:** cung cấp các thao tác Nhận diện đồ vật, Tìm đồ vật, Đọc văn bản và Dừng đọc; hỗ trợ TalkBack, nhãn tiếng Việt, thứ tự focus rõ ràng và vùng chạm tối thiểu 48 x 48 dp.
2. **Nhận diện đồ vật:** xử lý khung hình camera bằng mô hình TensorFlow Lite/LiteRT trên thiết bị; chỉ báo các lớp được hỗ trợ và vượt ngưỡng tin cậy.
3. **Tìm đồ vật:** ánh xạ câu lệnh tiếng Việt được hỗ trợ, ví dụ “Tìm chai nước”, vào class ID của mô hình; chỉ thông báo thành công khi tìm thấy đúng đối tượng yêu cầu.
4. **Vị trí tương đối:** chia chiều ngang khung hình thành ba vùng trái, giữa và phải theo tâm bounding box; đây không phải phép đo khoảng cách.
5. **Đọc văn bản:** dùng Google ML Kit Text Recognition theo cấu hình on-device để OCR, rồi đọc kết quả bằng Text-to-Speech tiếng Việt. Người dùng luôn có thể dừng phát âm thanh.
6. **Xử lý không chắc chắn:** khi ảnh tối, mờ, lệch hoặc kết quả dưới ngưỡng, ứng dụng đưa hướng dẫn điều chỉnh thay vì khẳng định kết quả.
7. **Ngoại tuyến và lưu cục bộ:** không yêu cầu tài khoản; chỉ lưu cục bộ các cài đặt như tốc độ đọc, âm lượng, ngôn ngữ, phản hồi âm thanh và cấu hình chống lặp.

## Phạm vi nhận diện và tìm vật v1

| Nhóm | Lớp đồ vật |
| --- | --- |
| Đồ dùng cá nhân | Phone, Backpack |
| Đồ uống | Bottle, Cup |
| Đồ ăn | Apple, Banana |
| Đồ dùng gia đình | Chair, Table (bàn ăn), Book, Remote |
| Thiết bị điện tử | Laptop, Keyboard, Mouse |
| Vật dụng khác | Clock, Scissors, Umbrella |

V1 giới hạn ở 16 lớp trên. Wallet, Keys và Bread được dời sang phiên bản sau và
không có trong danh sách chọn mục tiêu. Yêu cầu trực tiếp tới detector cho các
lớp này trả kết quả chưa hỗ trợ. Khi tích hợp giọng nói, ánh xạ dự kiến gồm
“Tìm chai nước” → `Bottle`, “Tìm điện thoại” → `Phone`, “Tìm quyển sách” →
`Book` và “Tìm cái ghế” → `Chair`.

## Yêu cầu phi chức năng

- **Khả năng tiếp cận:** mọi chức năng cốt lõi phải có phương án điều khiển cảm ứng khi Speech-to-Text ngoại tuyến không khả dụng; không dùng màu sắc làm kênh thông tin duy nhất.
- **Riêng tư:** không log, lưu hoặc truyền khung hình camera trong các luồng MVP; không đồng bộ lịch sử hoặc cài đặt lên đám mây.
- **Hiệu năng tương tác:** xử lý khung hình bất đồng bộ và giới hạn tần suất inference để giao diện phản hồi được, âm thanh dễ nghe và không chồng lấn.
- **Độ ổn định phản hồi:** cấu hình thử nghiệm ban đầu là ngưỡng confidence 0,50, ba frame ổn định và chống lặp trong 2 giây; các giá trị phải được benchmark trước khi chốt.
- **Thiết bị mục tiêu:** Android API 29+ (Android 10+), ARM64, RAM từ 4 GB, camera autofocus và đủ bộ nhớ cho ứng dụng/mô hình. Samsung, Xiaomi và OPPO là nhóm thiết bị kiểm thử đại diện; đây chưa phải cam kết tương thích.

## Công nghệ và kiến trúc định hướng

- Flutter với Dart 3; Riverpod 2 là cơ chế quản lý state mục tiêu của SeeMate AI.
- Camera Android để lấy khung hình sau khi được cấp quyền.
- TensorFlow Lite/LiteRT cho nhận diện đồ vật on-device.
- Google ML Kit Text Recognition cho OCR on-device.
- Speech-to-Text cho lệnh thoại và Text-to-Speech cho phản hồi tiếng Việt.
- SharedPreferences cho cài đặt cục bộ; SQLite/Drift chỉ được xem xét cho lịch sử cục bộ sau MVP.

Repository được khởi tạo từ Flutter Agentic Starter và đã dùng Riverpod 2 cho presentation state. GetIt/Injectable chỉ đảm nhiệm dependency composition; không đưa Signals trở lại các feature mới.

## Giới hạn và ngoài phạm vi

- Không đo khoảng cách, độ sâu, kích thước vật thể hoặc đưa ra lộ trình đi lại an toàn.
- Không thay thế gậy trắng, chó dẫn đường, huấn luyện định hướng-di chuyển hoặc thiết bị hỗ trợ chuyên dụng.
- Không bảo đảm phát hiện tất cả vật cản, đồ vật hoặc văn bản trong mọi điều kiện ánh sáng và góc camera.
- Không có xử lý ảnh đám mây, tài khoản người dùng, đồng bộ đa thiết bị, lưu ảnh camera hoặc lịch sử nhận diện trong MVP.
- Không cam kết Speech-to-Text hoạt động ngoại tuyến trên mọi thiết bị Android.
- Không nhận diện khuôn mặt, cảm xúc, xác thực tiền tệ, chẩn đoán y khoa hoặc đưa ra quyết định an toàn quan trọng.
- Không phát hành iOS, web, desktop hoặc wearable trong MVP.

## Tiêu chí nghiệm thu cấp dự án

1. Trên thiết bị Android mục tiêu ở chế độ máy bay, object detection và OCR chạy được khi tài nguyên cần thiết đã cài đặt và không tạo yêu cầu mạng.
2. Người dùng hoàn tất được ba tác vụ: tìm một đồ vật được hỗ trợ, đọc đoạn văn bản ngắn và dừng phản hồi giọng nói bằng lệnh hoặc điều khiển cảm ứng.
3. Kết quả vị trí trái/giữa/phải chính xác từ 90% số lượt thử có detection đạt ngưỡng trong bộ cảnh kiểm thử đại diện.
4. Ít nhất 80% người kiểm thử mục tiêu hoặc accessibility proxy hoàn thành từng tác vụ cốt lõi mà không cần hỗ trợ sau onboarding.
5. Không còn lỗi accessibility P0/P1 tại thời điểm đánh giá MVP; `flutter analyze` và các test tự động liên quan phải thành công.

## Kiểm thử và an toàn người dùng

Phương pháp đo detection/OCR, bộ cảnh, thiết bị, độ trễ và quy trình thử nghiệm người dùng nằm trong [Evaluation protocol](evaluation-protocol.md). Các tiêu chí nghiệm thu ở trên vẫn chờ bằng chứng, bao gồm kết quả đủ 16 lớp trên bản tích hợp chạy trên thiết bị Android thật. Ngưỡng chất lượng, hiệu năng và quy mô thử nghiệm bổ sung trong PRD 9.6 cần được xác nhận qua pilot.

Kiểm thử phải bao gồm object detection, OCR, lệnh thoại, Text-to-Speech, quyền camera, chế độ máy bay và TalkBack. Nếu mời người khiếm thị hoặc người có thị lực suy giảm tham gia, cần có sự đồng ý tự nguyện, giải thích mục đích, bảo vệ dữ liệu cá nhân và chỉ dùng các nhiệm vụ an toàn như tìm chai nước trên bàn, tìm điện thoại trong khung hình hoặc đọc nhãn sản phẩm. Không yêu cầu người tham gia thực hiện nhiệm vụ di chuyển nguy hiểm.
