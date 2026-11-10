import 'package:flutter_agentic_starter/core/speech/fake_tts_engine.dart';
import 'package:flutter_agentic_starter/core/speech/offline_tts_adapter.dart';
import 'package:flutter_agentic_starter/core/speech/speech_coordinator.dart';
import 'package:flutter_agentic_starter/core/speech/tts_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpeechCoordinator', () {
    late FakeTtsEngine engine;
    late SpeechCoordinator coordinator;

    setUp(() {
      engine = FakeTtsEngine();
      coordinator = SpeechCoordinator(engine: engine);
      coordinator.initialize();
    });

    tearDown(() async {
      await coordinator.dispose();
    });

    test('speakDirect speaks text via engine', () async {
      await coordinator.speakDirect('Xin chào');
      expect(engine.spokenTexts, contains('Xin chào'));
    });

    test('stop clears queue and invokes engine stop', () async {
      await coordinator.speakDirect('Câu 1');
      await coordinator.speakDirect('Câu 2');
      await coordinator.stop();
      expect(engine.stopCount, greaterThanOrEqualTo(1));
    });

    test('speakDirect bypasses duplicate suppression', () async {
      await coordinator.speakDirect('Nội dung giống nhau');
      await coordinator.speakDirect('Nội dung giống nhau');
      expect(engine.spokenTexts.length, equals(2));
    });

    test('announceDetection is suppressed within window for same (objectKey, zone)', () async {
      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);
      var currentTime = baseTime;

      final customCoordinator = SpeechCoordinator(
        engine: engine,
        settings: const SpeechSettings(
          suppressionEnabled: true,
          suppressionWindowSeconds: 3,
        ),
        clock: () => currentTime,
      );
      customCoordinator.initialize();
      addTearDown(customCoordinator.dispose);

      await customCoordinator.announceDetection(
        text: 'Ghế ở bên trái',
        objectKey: 'chair',
        zone: 'left',
      );
      expect(engine.spokenTexts.length, equals(1));

      // 1 second later (inside 3s window)
      currentTime = baseTime.add(const Duration(seconds: 1));
      await customCoordinator.announceDetection(
        text: 'Ghế ở bên trái',
        objectKey: 'chair',
        zone: 'left',
      );
      // Should be suppressed
      expect(engine.spokenTexts.length, equals(1));
    });

    test('announceDetection triggers again after window expires', () async {
      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);
      var currentTime = baseTime;

      final customCoordinator = SpeechCoordinator(
        engine: engine,
        settings: const SpeechSettings(
          suppressionEnabled: true,
          suppressionWindowSeconds: 3,
        ),
        clock: () => currentTime,
      );
      customCoordinator.initialize();
      addTearDown(customCoordinator.dispose);

      await customCoordinator.announceDetection(
        text: 'Ghế ở bên trái',
        objectKey: 'chair',
        zone: 'left',
      );
      expect(engine.spokenTexts.length, equals(1));

      // 4 seconds later (outside 3s window)
      currentTime = baseTime.add(const Duration(seconds: 4));
      await customCoordinator.announceDetection(
        text: 'Ghế ở bên trái',
        objectKey: 'chair',
        zone: 'left',
      );
      expect(engine.spokenTexts.length, equals(2));
    });

    test('different zone is not suppressed', () async {
      await coordinator.announceDetection(
        text: 'Ghế bên trái',
        objectKey: 'chair',
        zone: 'left',
      );
      await coordinator.announceDetection(
        text: 'Ghế ở giữa',
        objectKey: 'chair',
        zone: 'center',
      );
      expect(engine.spokenTexts.length, equals(2));
    });

    test('different objectKey in same zone is not suppressed', () async {
      await coordinator.announceDetection(
        text: 'Ghế bên trái',
        objectKey: 'chair',
        zone: 'left',
      );
      await coordinator.announceDetection(
        text: 'Chai nước bên trái',
        objectKey: 'bottle',
        zone: 'left',
      );
      expect(engine.spokenTexts.length, equals(2));
    });

    test('feedbackEnabled false skips detection announcements', () async {
      coordinator.updateSettings(
        const SpeechSettings(feedbackEnabled: false),
      );
      await coordinator.announceDetection(
        text: 'Chai nước ở giữa',
        objectKey: 'bottle',
        zone: 'center',
      );
      expect(engine.spokenTexts, isEmpty);
    });

    test('resetSession clears suppression history', () async {
      final baseTime = DateTime(2026, 1, 1, 12, 0, 0);
      var currentTime = baseTime;

      final customCoordinator = SpeechCoordinator(
        engine: engine,
        settings: const SpeechSettings(suppressionWindowSeconds: 60),
        clock: () => currentTime,
      );
      customCoordinator.initialize();
      addTearDown(customCoordinator.dispose);

      await customCoordinator.announceDetection(
        text: 'Ví ở bên phải',
        objectKey: 'wallet',
        zone: 'right',
      );
      expect(engine.spokenTexts.length, equals(1));

      customCoordinator.resetSession();

      // Immediately call again; should not be suppressed because session was reset
      await customCoordinator.announceDetection(
        text: 'Ví ở bên phải',
        objectKey: 'wallet',
        zone: 'right',
      );
      expect(engine.spokenTexts.length, equals(2));
    });

    test('coordinator returns TtsAlreadyDisposed when called after dispose', () async {
      await coordinator.dispose();
      final result = await coordinator.speakDirect('Hello');
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), isA<TtsAlreadyDisposed>());
    });
  });

  group('OfflineTtsAdapter fallback & readiness', () {
    test('reports missingEngine before native plugin is wired', () async {
      final adapter = OfflineTtsAdapter();
      final readiness = await adapter.initialize(pluginInstance: null);
      expect(readiness, equals(TtsReadiness.missingEngine));

      final speakResult = await adapter.speak('Test');
      expect(speakResult.isLeft(), isTrue);
      expect(speakResult.getLeft().toNullable(), isA<TtsNotReady>());

      await adapter.dispose();
      expect(await adapter.checkReadiness(), equals(TtsReadiness.disposed));
    });
  });
}
