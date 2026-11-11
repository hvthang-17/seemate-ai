import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/assistance_contracts.dart';

void main() {
  group('CameraFrame lifecycle and release', () {
    test('calls onRelease callback once and sets isReleased flag', () {
      int releaseCallCount = 0;
      final frame = createFakeCameraFrame(
        onRelease: () {
          releaseCallCount++;
        },
      );

      expect(frame.isReleased, isFalse);
      frame.release();
      expect(frame.isReleased, isTrue);
      expect(releaseCallCount, 1);

      // Subsequent release call must be a no-op
      frame.release();
      expect(releaseCallCount, 1);
    });
  });

  group('FakeTextReader', () {
    test('returns canned OCR result', () async {
      final reader = FakeTextReader(
        cannedResult: const OcrResult(fullText: 'SeeMate OCR'),
      );
      final frame = createFakeCameraFrame();

      final result = await reader.readText(frame);
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected success'),
        (res) => expect(res.fullText, 'SeeMate OCR'),
      );
    });

    test('handles cancellation token', () async {
      final reader = FakeTextReader();
      final frame = createFakeCameraFrame();
      final cancelToken = CancellationToken()..cancel();

      final result = await reader.readText(frame, cancelToken: cancelToken);
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<OcrCancelledFailure>()),
        (_) => fail('Expected cancelled failure'),
      );
    });
  });

  group('FakeAssistancePreferencesRepository', () {
    test('loads default preferences and persists updates', () async {
      final repo = FakeAssistancePreferencesRepository();

      final initial = await repo.loadPreferences();
      expect(initial.isRight(), isTrue);
      initial.fold(
        (_) => fail('Expected success'),
        (prefs) {
          expect(prefs.confidenceThreshold, 0.50);
          expect(prefs.duplicateSuppressionInterval, const Duration(seconds: 2));
        },
      );

      const updated = AssistancePreferences(
        confidenceThreshold: 0.70,
        duplicateSuppressionInterval: Duration(seconds: 3),
        speechRate: 1.2,
      );

      final saveResult = await repo.savePreferences(updated);
      expect(saveResult.isRight(), isTrue);

      final reloaded = await repo.loadPreferences();
      reloaded.fold(
        (_) => fail('Expected success'),
        (prefs) {
          expect(prefs.confidenceThreshold, 0.70);
          expect(prefs.duplicateSuppressionInterval, const Duration(seconds: 3));
          expect(prefs.speechRate, 1.2);
        },
      );
    });
  });
}
