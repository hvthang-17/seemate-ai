import 'package:flutter/material.dart' hide ObjectKey;
import 'package:flutter_agentic_starter/core/camera/camera_session_controller.dart';
import 'package:flutter_agentic_starter/core/permissions/permission_service.dart';
import 'package:flutter_agentic_starter/features/assistance/presentation/assistance_camera_panel.dart';
import 'package:flutter_agentic_starter/features/assistance/presentation/assistance_camera_providers.dart';
import 'package:flutter_agentic_starter/features/assistance/presentation/assistance_providers.dart';
import 'package:flutter_agentic_starter/features/assistance/presentation/assistance_screen.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/assistance_contracts.dart';
import 'package:flutter_agentic_starter/shared/i18n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('announces detections and captures one frame in text mode', (
    tester,
  ) async {
    final driver = FakeCameraDriverAdapter();
    final coordinator = FakeSpeechCoordinator();
    final voice = FakeVoiceCommandService();
    final reader = FakeTextReader();
    addTearDown(coordinator.dispose);
    final detector = FakeObjectDetector(
      cannedDetections: const [
        DetectedObject(
          key: ObjectKey.bottle,
          label: 'bottle',
          confidence: 0.91,
          boundingBox: BoundingBox(
            left: 0.6,
            top: 0.2,
            width: 0.3,
            height: 0.5,
          ),
          zone: HorizontalZone.right,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        cameraDriverProvider.overrideWithValue(driver),
        cameraPermissionProvider.overrideWithValue(
          _CameraPermission()..status = AppPermissionStatus.granted,
        ),
        cameraDetectionEnabledProvider.overrideWithValue(true),
        objectDetectorProvider.overrideWithValue(detector),
        speechCoordinatorProvider.overrideWithValue(coordinator),
        voiceCommandProvider.overrideWithValue(voice),
        textReaderProvider.overrideWithValue(reader),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AssistanceScreen(),
        ),
      ),
    );
    Future<void> say(String command) async {
      voice.enqueueResult(CommandResult.parse(command));
      await tester.tap(find.byTooltip('Speak a command'));
      await tester.pump();
    }

    await say('nhận diện đồ vật');
    await tester.pumpAndSettle();
    expect(driver.isStreaming, isTrue);

    final session = container.read(cameraSessionProvider)!;
    final frame = createFakeCameraFrame(sessionId: session.currentSessionId!);
    driver.emitSyntheticFrame(frame);
    await tester.pumpAndSettle();
    expect(frame.isReleased, isTrue);
    expect(find.text('91%'), findsOneWidget);
    await tester.tap(find.text('Detection details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('0.600, 0.200, 0.900, 0.700'), findsOneWidget);
    expect(coordinator.spokenUtterances, ['chai nước bên phải']);

    await say('dừng đọc');
    await tester.pumpAndSettle();
    detector.cannedDetections = const [
      DetectedObject(
        key: ObjectKey.cup,
        label: 'cup',
        confidence: 0.88,
        boundingBox: BoundingBox(left: .1, top: .2, width: .2, height: .3),
        zone: HorizontalZone.left,
      ),
    ];
    driver.emitSyntheticFrame();
    await tester.pumpAndSettle();
    expect(find.text('88%'), findsOneWidget);
    expect(coordinator.spokenUtterances, ['chai nước bên phải']);

    await say('đọc văn bản');
    await tester.pumpAndSettle();
    expect(driver.isStreaming, isFalse);

    expect(find.text('Capture and read text'), findsOneWidget);
    await say('chụp');
    expect(driver.isStreaming, isTrue);
    driver.emitSyntheticFrame();
    driver.emitSyntheticFrame();
    await tester.pumpAndSettle();
    expect(driver.isStreaming, isFalse);
    expect(reader.receivedFrames.single.isReleased, isTrue);
    expect(find.text('Xin chào SeeMate AI'), findsOneWidget);
    expect(coordinator.spokenUtterances.last, 'Xin chào SeeMate AI');

    await tester.tap(find.text('Stop reading'));
    await tester.pumpAndSettle();
    expect(coordinator.stopCallCount, greaterThanOrEqualTo(4));
    expect(coordinator.currentState, SpeechState.idle);

    await say('tìm chai nước');
    await tester.pumpAndSettle();
    expect(
      container.read(assistanceNotifierProvider).targetKey,
      ObjectKey.bottle,
    );
    await say('quay lại');
    await tester.pumpAndSettle();
    expect(container.read(assistanceNotifierProvider).targetKey, isNull);
    expect(driver.isClosed, isTrue);
    expect(coordinator.currentState, SpeechState.idle);
  });

  testWidgets('permission denial and revocation keep the camera closed', (
    tester,
  ) async {
    final permission = _CameraPermission();
    final driver = FakeCameraDriverAdapter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cameraDriverProvider.overrideWithValue(driver),
          cameraPermissionProvider.overrideWithValue(permission),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AssistanceCameraPanel(active: true, child: SizedBox.shrink()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(driver.isStreaming, isFalse);
    expect(permission.requests, 1);

    permission.status = AppPermissionStatus.granted;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Camera preview is ready'), findsOneWidget);
    expect(driver.isClosed, isFalse);

    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(driver.isClosed, isTrue);

    permission.status = AppPermissionStatus.permanentlyDenied;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(driver.isStreaming, isFalse);
    expect(permission.requests, 1);

    await tester.tap(find.text('Open Settings'));
    expect(permission.settingsOpens, 1);
  });
}

class _CameraPermission implements PermissionService {
  AppPermissionStatus status = AppPermissionStatus.denied;
  int requests = 0;
  int settingsOpens = 0;

  @override
  Future<AppPermissionStatus> check(AppPermission permission) async => status;

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async {
    requests++;
    return status;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpens++;
    return true;
  }
}
