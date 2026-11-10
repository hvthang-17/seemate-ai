import '../models/ocr_result.dart';
import '../repositories/text_reading_repository.dart';

/// Clean Architecture use case to recognize printed text from a camera frame.
///
/// Note: This use case is purely responsible for text extraction.
/// It returns an [OcrResult] to the caller (N1) which decides
/// whether to display it and pass it to [SpeechCoordinator.speakDirect].
final class ReadPrintedText {
  const ReadPrintedText(this._repository);

  final TextReadingRepository _repository;

  Future<OcrResult> call(OcrInput input) => _repository.recognizeText(input);
}
