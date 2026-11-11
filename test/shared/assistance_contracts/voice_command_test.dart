import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/assistance_contracts.dart';

void main() {
  group('CommandResult parser', () {
    test('parses return home and rejects incomplete command matches', () {
      expect(
        CommandResult.parse('QUAY LẠI!').action,
        AssistanceAction.returnHome,
      );
      expect(CommandResult.parse('tôi nói quay lại').isUnderstood, isFalse);
      expect(CommandResult.parse('quay lại đi đâu').isUnderstood, isFalse);
    });
    test('parses stopReading commands', () {
      final res1 = CommandResult.parse('dừng đọc');
      expect(res1.action, AssistanceAction.stopReading);
      expect(res1.isUnderstood, isTrue);

      final res2 = CommandResult.parse('ngừng phát âm');
      expect(res2.action, AssistanceAction.stopReading);
    });

    test('parses readText commands', () {
      final res = CommandResult.parse('đọc văn bản');
      expect(res.action, AssistanceAction.readText);
      expect(res.isUnderstood, isTrue);
    });

    test(
      'normalizes short capture commands without mistaking them for read',
      () {
        expect(
          CommandResult.parse('  CHỤP   VÀ ĐỌC VĂN BẢN! ').action,
          AssistanceAction.captureText,
        );
        expect(
          CommandResult.parse('chụp').action,
          AssistanceAction.captureText,
        );
        expect(CommandResult.parse('tôi đang đọc sách').isUnderstood, isFalse);
        expect(CommandResult.parse('tìm nước ngọt').isSupported, isFalse);
      },
    );

    test('parses recognizeObjects commands', () {
      final res = CommandResult.parse('nhận diện đồ vật');
      expect(res.action, AssistanceAction.recognizeObjects);
      expect(res.isUnderstood, isTrue);
    });

    test('parses findObject command with supported target', () {
      final res = CommandResult.parse('tìm chai nước');
      expect(res.action, AssistanceAction.findObject);
      expect(res.targetKey, ObjectKey.bottle);
      expect(res.isSupported, isTrue);
    });

    test('handles findObject command with unsupported target gracefully', () {
      final res = CommandResult.parse('tìm con mèo');
      expect(res.action, AssistanceAction.findObject);
      expect(res.targetKey, isNull);
      expect(res.isSupported, isFalse);
      expect(res.failureReason, isNotNull);
    });

    test('handles empty or unrecognized transcript', () {
      final resEmpty = CommandResult.parse('');
      expect(resEmpty.isUnderstood, isFalse);

      final resUnknown = CommandResult.parse('hôm nay thời tiết thế nào');
      expect(resUnknown.isUnderstood, isFalse);
    });
  });

  group('FakeVoiceCommandService', () {
    test('returns queued command result', () async {
      final service = FakeVoiceCommandService();
      service.enqueueResult(
        const CommandResult(
          isUnderstood: true,
          isSupported: true,
          action: AssistanceAction.readText,
        ),
      );

      final result = await service.listenForCommand();
      expect(result.action, AssistanceAction.readText);
    });
  });
}
