import 'dart:async';

import '../../../core/speech/speech_coordinator.dart';
import 'enhanced_ocr_result.dart';

/// Accessibility voice feedback manager for blind and visually impaired users.
///
/// Ensures:
/// - Concise, descriptive Vietnamese announcements guiding the user.
/// - Never overlaps with ongoing speech playback (interrupts gracefully).
/// - Suppresses rapid repeat announcements of the same warning.
/// - Implements specific required conversational prompts for unclear, conflicting, and readable results.
final class AccessibleOcrAnnouncer {
  AccessibleOcrAnnouncer({
    required SpeechCoordinator speechCoordinator,
    this.suppressionCooldown = const Duration(seconds: 4),
    DateTime Function()? clock,
  })  : _coordinator = speechCoordinator,
        _clock = clock ?? DateTime.now;

  final SpeechCoordinator _coordinator;
  final Duration suppressionCooldown;
  final DateTime Function() _clock;

  String? _lastAnnouncedText;
  DateTime? _lastAnnouncedTime;

  /// Announces the outcome of an OCR operation with helpful, non-patronizing guidance.
  Future<void> announceOcrOutcome(EnhancedOcrResult result) async {
    // 1. If empty result
    if (result.isEmpty) {
      if (result.qualityResult.isTooDark) {
        await _announce(
          'Ảnh chưa đủ rõ vì hơi tối. Hãy chuyển tới nơi có thêm ánh sáng và thử lại.',
        );
      } else if (result.qualityResult.isPotentiallyBlurry) {
        await _announce('Ảnh chưa đủ rõ. Hãy giữ điện thoại ổn định và thử lại.');
      } else {
        await _announce('Không phát hiện chữ in nào trong ảnh. Bạn có thể chụp lại gần hơn.');
      }
      return;
    }

    // 2. If OCR failed
    if (result.isFailure) {
      await _announce('Không thể nhận diện ảnh. Vui lòng thử lại.');
      return;
    }

    // 3. For unclear input (blurry or poorly focused)
    if (result.qualityResult.isPotentiallyBlurry) {
      await _announce('Ảnh chưa đủ rõ. Hãy giữ điện thoại ổn định và thử lại.');
      return;
    }

    // 4. For conflicting OCR results or low certainty
    if (result.hasConflictingCandidates || result.certainty == OcrCertainty.low) {
      await _announce(
        'Một số chữ chưa được nhận diện chắc chắn. Bạn có thể nghe kết quả tạm thời hoặc quét lại.',
      );
      return;
    }

    // 5. For readable results
    await _announce('Đã nhận diện văn bản. Bắt đầu đọc.');
  }

  /// Speaks a specific instructional guide message.
  Future<void> announceMessage(String message) => _announce(message);

  /// Stops any speech announcement immediately.
  Future<void> stop() => _coordinator.stop();

  Future<void> _announce(String text) async {
    final now = _clock();
    if (_lastAnnouncedText == text && _lastAnnouncedTime != null) {
      final elapsed = now.difference(_lastAnnouncedTime!);
      if (elapsed < suppressionCooldown) {
        // Suppress rapid duplicate repeat warning
        return;
      }
    }

    _lastAnnouncedText = text;
    _lastAnnouncedTime = now;

    // Interrupt current playback and speak announcement cleanly
    await _coordinator.stop();
    await _coordinator.speakDirect(text);
  }
}
