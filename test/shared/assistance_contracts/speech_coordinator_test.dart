import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/assistance_contracts.dart';

void main() {
  group('FakeSpeechCoordinator duplicate suppression', () {
    test('speaks first detection and suppresses duplicate within interval', () async {
      DateTime simulatedTime = DateTime(2026, 11, 8, 10, 0, 0);

      final coordinator = FakeSpeechCoordinator(
        suppressionInterval: const Duration(seconds: 2),
        nowProvider: () => simulatedTime,
      );

      const key = SuppressionKey(
        objectKey: ObjectKey.bottle,
        zone: HorizontalZone.left,
      );

      // First announcement -> should speak
      final spokenFirst = await coordinator.speak(
        'chai nước bên trái',
        suppressionKey: key,
      );
      expect(spokenFirst, isTrue);
      expect(coordinator.spokenUtterances.length, 1);

      // Advance 1 second (< 2 seconds) -> duplicate should be suppressed
      simulatedTime = simulatedTime.add(const Duration(seconds: 1));
      final spokenDuplicate = await coordinator.speak(
        'chai nước bên trái',
        suppressionKey: key,
      );
      expect(spokenDuplicate, isFalse);
      expect(coordinator.spokenUtterances.length, 1);

      // Advance 1.5 more seconds (total 2.5s > 2s) -> should speak again
      simulatedTime = simulatedTime.add(const Duration(milliseconds: 1500));
      final spokenAfterInterval = await coordinator.speak(
        'chai nước bên trái',
        suppressionKey: key,
      );
      expect(spokenAfterInterval, isTrue);
      expect(coordinator.spokenUtterances.length, 2);
    });

    test('immediately speaks when zone changes even if within 2 seconds', () async {
      DateTime simulatedTime = DateTime(2026, 11, 8, 10, 0, 0);

      final coordinator = FakeSpeechCoordinator(
        suppressionInterval: const Duration(seconds: 2),
        nowProvider: () => simulatedTime,
      );

      const keyLeft = SuppressionKey(
        objectKey: ObjectKey.bottle,
        zone: HorizontalZone.left,
      );
      const keyCenter = SuppressionKey(
        objectKey: ObjectKey.bottle,
        zone: HorizontalZone.center,
      );

      // Spoken on left
      final spokenLeft = await coordinator.speak(
        'chai nước bên trái',
        suppressionKey: keyLeft,
      );
      expect(spokenLeft, isTrue);

      // Object moves to center 500ms later -> different key, must speak immediately
      simulatedTime = simulatedTime.add(const Duration(milliseconds: 500));
      final spokenCenter = await coordinator.speak(
        'chai nước ở giữa',
        suppressionKey: keyCenter,
      );
      expect(spokenCenter, isTrue);
      expect(coordinator.spokenUtterances.length, 2);
    });

    test('stop immediately updates state and increases stopCallCount', () async {
      final coordinator = FakeSpeechCoordinator();

      await coordinator.speak('đang đọc văn bản dài');
      expect(coordinator.currentState, SpeechState.speaking);

      await coordinator.stop();
      expect(coordinator.stopCallCount, 1);
      expect(coordinator.currentState, SpeechState.idle);
    });
  });
}
