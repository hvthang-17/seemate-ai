// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get helloWorld => 'Xin chào!';

  @override
  String get displaySomeText => 'Hiển thị văn bản!';

  @override
  String get homeTitle => 'SeeMate AI';

  @override
  String get usageGuideTitle => 'Hướng dẫn sử dụng';

  @override
  String get usageGuideListen => 'Nghe hướng dẫn';

  @override
  String get usageGuideClose => 'Đóng hướng dẫn';

  @override
  String get usageGuideText =>
      'Chào mừng bạn đến với SeeMate AI. Chọn Nhận diện đồ vật để nghe tên những vật trong khung hình. Chọn Tìm đồ vật và chọn vật bạn muốn tìm để nghe vị trí của vật trong khung hình.\n\nĐể nghe đọc chữ in, chọn Đọc văn bản, hướng máy ảnh vào trang giấy rồi chọn Chụp và đọc văn bản. Nút Dừng đọc sẽ ngắt giọng nói.\n\nNếu bản cài hỗ trợ lệnh giọng nói, chạm Nói lệnh, đợi máy rung rồi nói lệnh. SeeMate AI không dùng để dẫn đường hoặc tránh chướng ngại vật.';

  @override
  String get chooseAssistanceMode => 'Bạn muốn làm gì?';

  @override
  String get recognizeDescription => 'Nghe tên đồ vật trước mặt';

  @override
  String get findDescription => 'Chọn một đồ vật và nghe vị trí';

  @override
  String get readDescription => 'Chụp văn bản để nghe đọc';

  @override
  String get detectionDetails => 'Chi tiết nhận diện';

  @override
  String get homeLoadCities => 'Tải danh sách thành phố';

  @override
  String get homeLoadError =>
      'Không thể tải danh sách thành phố. Vui lòng thử lại.';

  @override
  String get retry => 'Thử lại';

  @override
  String get modeRecognize => 'Nhận diện đồ vật';

  @override
  String get modeFind => 'Tìm đồ vật';

  @override
  String get modeRead => 'Đọc văn bản';

  @override
  String get modeStop => 'Dừng đọc';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get selectTargetTitle => 'Chọn đồ vật muốn tìm';

  @override
  String get cameraPermissionPrompt =>
      'SeeMate AI cần quyền máy ảnh để nhận diện đồ vật và đọc chữ.';

  @override
  String get cameraPermissionDeniedPermanent =>
      'Quyền máy ảnh đã bị từ chối vĩnh viễn. Vui lòng mở Cài đặt thiết bị để cấp quyền.';

  @override
  String get cameraOpening => 'Đang mở máy ảnh.';

  @override
  String get cameraPreviewReady => 'Đã mở máy ảnh.';

  @override
  String get captureText => 'Chụp và đọc văn bản';

  @override
  String get voiceListen => 'Nói lệnh';

  @override
  String get voicePreparing => 'Đang chuẩn bị micro. Chạm để hủy';

  @override
  String get voiceCancel => 'Đang nghe. Chạm để hủy';

  @override
  String get voiceOfflineUnavailable =>
      'Bản này chưa có bộ nhận lệnh tiếng Việt ngoại tuyến.';

  @override
  String get voiceMicrophoneDenied =>
      'Cần quyền micro để nhận lệnh. Bạn có thể cấp quyền trong Cài đặt Android.';

  @override
  String get voiceNotUnderstood => 'Chưa hiểu lệnh. Hãy thử lại.';

  @override
  String get voiceCaptureRequiresTextMode =>
      'Hãy mở chế độ Đọc văn bản trước khi nói Chụp.';

  @override
  String get ocrCaptureFailed =>
      'Không lấy được ảnh. Hãy giữ máy ổn định và thử lại.';

  @override
  String get ocrReadFailed =>
      'Không đọc được văn bản trong ảnh. Hãy thử lại với chữ rõ hơn.';

  @override
  String get offlineVoiceUnavailable =>
      'Chưa có giọng tiếng Việt ngoại tuyến. Hãy cài giọng tiếng Việt trong phần cài đặt chuyển văn bản thành giọng nói của thiết bị.';

  @override
  String get cameraDetectionReady => 'Máy ảnh đang hoạt động.';

  @override
  String get detectionModelUnavailable =>
      'Bản này chưa có mô hình nhận diện đồ vật trên thiết bị.';

  @override
  String get detectionInitializationFailed =>
      'Không khởi động được bộ nhận diện. Hãy mở lại ứng dụng để thử lại.';

  @override
  String get detectionFailed =>
      'Chưa thể nhận diện đồ vật. Hãy thử hướng lại máy ảnh.';

  @override
  String get detectionWaiting => 'Đang chờ kết quả nhận diện đầu tiên.';

  @override
  String detectionBounds(String label, String coordinates) {
    return 'Nhãn mô hình: $label. Khung vật thể (trái, trên, phải, dưới): $coordinates';
  }

  @override
  String get cameraPaused => 'Máy ảnh đang tạm dừng.';

  @override
  String get cameraUnavailable =>
      'Không mở được máy ảnh. Hãy đóng ứng dụng khác đang dùng máy ảnh rồi thử lại.';

  @override
  String get openSettings => 'Mở cài đặt';

  @override
  String get noDetectionFeedback =>
      'Không nhận diện rõ. Hãy đưa máy gần hơn hoặc tăng ánh sáng.';

  @override
  String get unsupportedObject => 'Vật thể này hiện chưa được hỗ trợ tìm kiếm.';

  @override
  String get ocrEmptyFeedback =>
      'Không tìm thấy văn bản nào trong ảnh. Hãy thử lại rõ nét hơn.';

  @override
  String get speechRateLabel => 'Tốc độ đọc giọng nói';

  @override
  String get duplicateSuppressionLabel =>
      'Khoảng thời gian chống lặp thông báo (giây)';

  @override
  String get save => 'Lưu';

  @override
  String get savedSuccess => 'Đã lưu cài đặt thành công';

  @override
  String get saveError => 'Không thể lưu cài đặt';

  @override
  String get settingsLoadError =>
      'Không thể tải cài đặt đã lưu. Hãy thử lại hoặc lưu cài đặt đang hiển thị.';
}
