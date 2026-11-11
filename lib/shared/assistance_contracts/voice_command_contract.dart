import 'object_detection_contract.dart';

/// Available assistance actions that can be triggered via speech or touch.
enum AssistanceAction {
  recognizeObjects('Nhận diện đồ vật'),
  findObject('Tìm đồ vật'),
  readText('Đọc văn bản'),
  stopReading('Dừng đọc'),
  captureText('Chụp'),
  returnHome('Quay lại');

  const AssistanceAction(this.vietnameseTitle);
  final String vietnameseTitle;
}

/// Result of parsing a spoken Vietnamese voice command.
class CommandResult {
  const CommandResult({
    required this.isUnderstood,
    required this.isSupported,
    this.action,
    this.targetKey,
    this.failureReason,
    this.failure,
  });

  final bool isUnderstood;
  final bool isSupported;
  final AssistanceAction? action;
  final ObjectKey? targetKey;
  final String? failureReason;
  final VoiceCommandFailure? failure;

  static const _actionsByPhrase = {
    'nhận diện đồ vật': AssistanceAction.recognizeObjects,
    'nhận diện': AssistanceAction.recognizeObjects,
    'đọc văn bản': AssistanceAction.readText,
    'đọc chữ': AssistanceAction.readText,
    'dừng đọc': AssistanceAction.stopReading,
    'ngừng đọc': AssistanceAction.stopReading,
    'ngừng phát âm': AssistanceAction.stopReading,
    'chụp': AssistanceAction.captureText,
    'chụp ảnh': AssistanceAction.captureText,
    'chụp và đọc văn bản': AssistanceAction.captureText,
    'quay lại': AssistanceAction.returnHome,
    'về màn hình chính': AssistanceAction.returnHome,
  };

  static const _targetAliases = {
    'chai': ObjectKey.bottle,
    'ly': ObjectKey.cup,
    'ghế': ObjectKey.chair,
    'bàn': ObjectKey.table,
    'bàn ăn': ObjectKey.table,
    'sách': ObjectKey.book,
    'ví': ObjectKey.wallet,
    'kéo': ObjectKey.scissors,
  };

  /// Helper to parse raw Vietnamese transcript into an [AssistanceAction] and optional [ObjectKey].
  static CommandResult parse(String transcript) {
    final text = transcript
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[.!?]+$'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) {
      return const CommandResult(
        isUnderstood: false,
        isSupported: false,
        failureReason: 'Không nghe thấy lệnh nào',
      );
    }

    final action = _actionsByPhrase[text];
    if (action != null) {
      return CommandResult(
        isUnderstood: true,
        isSupported: true,
        action: action,
      );
    }

    if (text.startsWith('tìm ')) {
      final name = text.substring(4);
      final targetKey = _findTarget(name);
      if (targetKey != null) {
        return CommandResult(
          isUnderstood: true,
          isSupported: true,
          action: AssistanceAction.findObject,
          targetKey: targetKey,
        );
      }
      return CommandResult(
        isUnderstood: true,
        isSupported: false,
        action: AssistanceAction.findObject,
        failureReason: 'Vật thể này hiện chưa được hỗ trợ tìm kiếm',
      );
    }

    return CommandResult(
      isUnderstood: false,
      isSupported: false,
      failureReason: 'Không nhận dạng được câu lệnh',
    );
  }

  static ObjectKey? _findTarget(String name) {
    for (final key in ObjectKey.values) {
      if (name == key.vietnameseLabel ||
          name == key.englishLabel.toLowerCase()) {
        return key;
      }
    }
    return _targetAliases[name];
  }
}

enum VoiceCommandFailure {
  unavailable,
  permissionDenied,
  timeout,
  audioUnavailable,
  cancelled,
  recognition,
}

/// Status of the short voice command session.
enum VoiceCommandStatus {
  idle,
  listening,
  processing,
  completed,
  unavailableOffline,
  error,
}

/// Contract for voice command recognition.
abstract interface class VoiceCommandContract {
  /// Checks whether on-device/offline speech recognition is supported on this Android device.
  Future<bool> isOfflineAvailable();

  /// Starts a short user-initiated voice listening session.
  ///
  /// Never automatically falls back to cloud recognition when offline is unavailable.
  Future<CommandResult> listenForCommand({
    Duration timeout = const Duration(seconds: 5),
    void Function()? onListening,
  });

  /// Immediately stops active listening.
  Future<void> stopListening();

  /// Releases microphone and speech recognition resources.
  void dispose();
}
