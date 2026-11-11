import 'package:flutter/material.dart' hide ObjectKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_agentic_starter/features/assistance/domain/models/assistance_state.dart';
import 'package:flutter_agentic_starter/features/assistance/presentation/assistance_providers.dart';
import 'package:flutter_agentic_starter/features/assistance/presentation/assistance_screen.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/assistance_contracts.dart';
import 'package:flutter_agentic_starter/shared/i18n/generated/app_localizations.dart';

void main() {
  testWidgets('stopping invalidates an OCR request before it can speak', (
    tester,
  ) async {
    final coordinator = FakeSpeechCoordinator();
    final reader = FakeTextReader(
      simulatedDelay: const Duration(milliseconds: 50),
    );
    final container = ProviderContainer(
      overrides: [
        speechCoordinatorProvider.overrideWithValue(coordinator),
        textReaderProvider.overrideWithValue(reader),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(coordinator.dispose);
    final notifier = container.read(assistanceNotifierProvider.notifier);
    notifier.selectMode(AssistanceMode.textReading);

    final frame = createFakeCameraFrame();
    final reading = notifier.captureAndReadText(() async => frame);
    await notifier.stopReading();
    await tester.pump(const Duration(milliseconds: 50));
    await reading;

    final state = container.read(assistanceNotifierProvider);
    expect(state.ocrResult, isNull);
    expect(state.isProcessing, isFalse);
    expect(coordinator.spokenUtterances, isEmpty);
    expect(frame.isReleased, isTrue);
  });

  testWidgets('switching modes drops an in-flight detection', (tester) async {
    final coordinator = FakeSpeechCoordinator();
    final detector = FakeObjectDetector(
      simulatedDelay: const Duration(milliseconds: 50),
      cannedDetections: const [
        DetectedObject(
          key: ObjectKey.bottle,
          label: 'Bottle',
          confidence: 0.88,
          boundingBox: BoundingBox(
            left: 0.1,
            top: 0.2,
            width: 0.2,
            height: 0.3,
          ),
          zone: HorizontalZone.left,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        speechCoordinatorProvider.overrideWithValue(coordinator),
        objectDetectorProvider.overrideWithValue(detector),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(coordinator.dispose);
    final notifier = container.read(assistanceNotifierProvider.notifier);
    notifier.selectMode(AssistanceMode.objectRecognition);

    final frame = createFakeCameraFrame();
    final detection = notifier.processFrame(frame);
    notifier.selectMode(AssistanceMode.textReading);
    await tester.pump(const Duration(milliseconds: 50));
    await detection;

    final state = container.read(assistanceNotifierProvider);
    expect(state.mode, AssistanceMode.textReading);
    expect(state.detectedObjects, isEmpty);
    expect(coordinator.spokenUtterances, isEmpty);
    expect(frame.isReleased, isTrue);
  });

  Widget buildTestSubject({
    required FakeSpeechCoordinator coordinator,
    required FakeObjectDetector detector,
    required FakeTextReader reader,
    FakeVoiceCommandService? voice,
  }) {
    return ProviderScope(
      overrides: [
        speechCoordinatorProvider.overrideWithValue(coordinator),
        objectDetectorProvider.overrideWithValue(detector),
        textReaderProvider.overrideWithValue(reader),
        if (voice != null) voiceCommandProvider.overrideWithValue(voice),
      ],
      child: const MaterialApp(
        locale: Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AssistanceScreen(),
      ),
    );
  }

  testWidgets('displays accessible mode buttons and stop reading control', (
    tester,
  ) async {
    final coordinator = FakeSpeechCoordinator();
    final detector = FakeObjectDetector();
    final reader = FakeTextReader();

    await tester.pumpWidget(
      buildTestSubject(
        coordinator: coordinator,
        detector: detector,
        reader: reader,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dừng đọc'), findsOneWidget);
    expect(find.text('Nhận diện đồ vật'), findsOneWidget);
    expect(find.text('Tìm đồ vật'), findsOneWidget);
    expect(find.text('Đọc văn bản'), findsOneWidget);

    // Verify touch target for stop reading is at least 48dp high
    final stopButtonSize = tester.getSize(find.byType(ElevatedButton).first);
    expect(stopButtonSize.height, greaterThanOrEqualTo(48.0));
  });

  testWidgets('target picker lists only the 16 v1 model classes', (
    tester,
  ) async {
    final coordinator = FakeSpeechCoordinator();
    final detector = FakeObjectDetector();
    final reader = FakeTextReader();

    await tester.pumpWidget(
      buildTestSubject(
        coordinator: coordinator,
        detector: detector,
        reader: reader,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tìm đồ vật'));
    await tester.pumpAndSettle();

    expect(find.text('Chọn đồ vật muốn tìm'), findsOneWidget);
    expect(find.text('chai nước'), findsOneWidget);
    expect(find.text('điện thoại'), findsOneWidget);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.childrenDelegate.estimatedChildCount, 16);
    expect(find.text('ví tiền'), findsNothing);
    expect(find.text('chìa khóa'), findsNothing);
    expect(find.text('bánh mì'), findsNothing);

    // Select chai nước
    await tester.tap(find.text('chai nước'));
    await tester.pumpAndSettle();

    expect(find.text('Đang tìm chai nước...'), findsOneWidget);
  });

  testWidgets('large text keeps modes reachable and stop pinned', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final coordinator = FakeSpeechCoordinator();
    final voice = FakeVoiceCommandService();
    addTearDown(coordinator.dispose);
    addTearDown(voice.dispose);
    await tester.pumpWidget(
      buildTestSubject(
        coordinator: coordinator,
        detector: FakeObjectDetector(),
        reader: FakeTextReader(),
        voice: voice,
      ),
    );
    await tester.pumpAndSettle();

    final mic = tester.getRect(find.byTooltip('Nói lệnh'));
    final settings = tester.getRect(find.byTooltip('Cài đặt'));
    expect(mic.size, const Size(64, 64));
    expect(settings.size, const Size(64, 64));
    expect(settings.left - mic.right, greaterThanOrEqualTo(16));

    final stop = find.widgetWithText(ElevatedButton, 'Dừng đọc');
    final stopBefore = tester.getRect(stop);
    expect(stopBefore.height, greaterThanOrEqualTo(48));
    final read = find.text('Đọc văn bản');
    await tester.scrollUntilVisible(read, 120);
    expect(tester.getRect(stop), stopBefore);
    await tester.tap(read);
    await tester.pumpAndSettle();
    expect(find.text('Bạn muốn làm gì?'), findsNothing);
    expect(stop.hitTestable(), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Bạn muốn làm gì?'), findsOneWidget);
  });

  testWidgets(
    'processes frame and displays detection results with relative position',
    (tester) async {
      final coordinator = FakeSpeechCoordinator();
      final detector = FakeObjectDetector(
        cannedDetections: [
          const DetectedObject(
            key: ObjectKey.bottle,
            label: 'Bottle',
            confidence: 0.88,
            boundingBox: BoundingBox(
              left: 0.1,
              top: 0.2,
              width: 0.2,
              height: 0.3,
            ),
            zone: HorizontalZone.left,
          ),
        ],
      );
      final reader = FakeTextReader();

      final container = ProviderContainer(
        overrides: [
          speechCoordinatorProvider.overrideWithValue(coordinator),
          objectDetectorProvider.overrideWithValue(detector),
          textReaderProvider.overrideWithValue(reader),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AssistanceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select recognition mode
      await tester.tap(find.text('Nhận diện đồ vật'));
      await tester.pump();

      // Process a test frame
      await container
          .read(assistanceNotifierProvider.notifier)
          .processFrame(createFakeCameraFrame());
      await tester.pumpAndSettle();

      expect(find.text('chai nước'), findsOneWidget);
      expect(find.text('Vị trí: bên trái'), findsOneWidget);
      expect(find.text('88%'), findsOneWidget);
    },
  );
}
