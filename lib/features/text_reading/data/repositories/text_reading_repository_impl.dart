import '../../domain/models/ocr_result.dart';
import '../../domain/repositories/text_reading_repository.dart';
import '../sources/mlkit_text_source.dart';

/// Concrete implementation of [TextReadingRepository] backed by [MlkitTextSource].
final class TextReadingRepositoryImpl implements TextReadingRepository {
  const TextReadingRepositoryImpl(this._source);

  final MlkitTextSource _source;

  @override
  Future<OcrResult> recognizeText(OcrInput input) =>
      _source.recognizeText(input);

  @override
  void cancelSession(String sessionId) => _source.cancelSession(sessionId);

  @override
  Future<void> dispose() => _source.dispose();
}
