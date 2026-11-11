import 'package:flutter/services.dart';
import 'package:flutter_agentic_starter/features/object_detection/data/mediapipe_object_detector.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/assistance_contracts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('seemate/test_detection');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final frame = createFakeCameraFrame(
    width: 4,
    height: 2,
    rotationDegrees: 90,
    planes: [
      FramePlane(bytes: Uint8List(12), bytesPerRow: 6, bytesPerPixel: 1),
      FramePlane(bytes: Uint8List(4), bytesPerRow: 4, bytesPerPixel: 2),
      FramePlane(bytes: Uint8List(4), bytesPerRow: 4, bytesPerPixel: 2),
    ],
  );
  var sequence = 0;
  CameraFrame nextFrame({String? sessionId, int? rotation}) =>
      createFakeCameraFrame(
        id: 'frame-${++sequence}',
        sessionId: sessionId ?? frame.sessionId,
        width: frame.width,
        height: frame.height,
        rotationDegrees: rotation ?? frame.rotationDegrees,
        planes: frame.planes,
      );
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'distinguishes a bundled detector startup error from a missing model',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'dispose') return null;
        throw PlatformException(code: 'detector_init_failed');
      });
      final detector = MediaPipeObjectDetector(channel: channel);
      addTearDown(detector.dispose);

      final outcome = await detector.detect(frame);
      expect(
        outcome.getLeft().toNullable(),
        isA<DetectorInitializationFailure>(),
      );
    },
  );

  test('passes YUV strides and maps only valid qualifying boxes', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'dispose') return null;
      expect(call.method, 'detect');
      final arguments = call.arguments as Map<Object?, Object?>;
      expect(arguments['rotation'], 90);
      final planes = arguments['planes'] as List<Object?>;
      expect(planes, hasLength(3));
      expect((planes.last as Map<Object?, Object?>)['pixelStride'], 2);
      return [
        _candidate('cell phone', 0.9, -0.1, 0.32),
        _candidate('bottle', 0.7, 0.72, 1.1),
        _candidate('wallet', 0.99, 0.5, 0.9),
        _candidate('cup', 0.4, 0.1, 0.4),
        _candidate('book', 0.9, 0.8, 0.7),
      ];
    });
    final detector = MediaPipeObjectDetector(channel: channel);
    addTearDown(detector.dispose);

    final pending = await detector.detect(nextFrame());
    expect(_success(pending).readiness, DetectionReadiness.stabilizing);
    expect(_success(pending).objects, isEmpty);
    final result = await detector.detect(nextFrame());
    result.match(
      (failure) => fail('Unexpected failure: ${failure.runtimeType}'),
      (result) {
        final objects = result.objects;
        expect(objects.map((item) => item.key), [
          ObjectKey.phone,
          ObjectKey.bottle,
        ]);
        expect(objects.first.boundingBox.left, 0);
        expect(objects.first.zone, HorizontalZone.left);
        expect(objects.last.confidence, 0.7);
        expect(objects.last.boundingBox.right, 1);
        expect(objects.last.zone, HorizontalZone.right);
      },
    );
  });

  test(
    'tracks same-class boxes independently as confidence order changes',
    () async {
      var candidates = <Map<String, Object>>[];
      messenger.setMockMethodCallHandler(channel, (_) async => candidates);
      final detector = MediaPipeObjectDetector(channel: channel);
      addTearDown(detector.dispose);
      final left = _candidate('chair', .50, .05, .25);
      final right = _candidate('chair', .90, .75, .95);
      final jitter = _candidate('chair', .51, .07, .27);

      candidates = [left];
      expect(_success(await detector.detect(nextFrame())).objects, isEmpty);
      candidates = [right, jitter];
      expect(
        _success(await detector.detect(nextFrame())).objects.single.zone,
        HorizontalZone.left,
      );
      candidates = [left, right];
      final result = _success(await detector.detect(nextFrame()));
      expect(result.objects.map((object) => object.zone), [
        HorizontalZone.right,
        HorizontalZone.left,
      ]);
      expect(result.objects.last.confidence, .50);

      candidates = [right];
      expect(
        _success(await detector.detect(nextFrame())).objects.single.zone,
        HorizontalZone.right,
      );
      candidates = [left];
      expect(
        _success(await detector.detect(nextFrame())).objects.single.zone,
        HorizontalZone.left,
      );
    },
  );

  test(
    'recognition confirms each current object despite one intervening miss',
    () async {
      final laptop = _candidate('laptop', .8, .55, .96);
      final bottle = _candidate('bottle', .65, .05, .25);
      final cup = _candidate('cup', .75, .34, .54);
      var candidates = [laptop, bottle];
      messenger.setMockMethodCallHandler(channel, (_) async => candidates);
      final detector = MediaPipeObjectDetector(channel: channel);
      addTearDown(detector.dispose);
      Future<List<ObjectKey>> detect() async => _success(
        await detector.detect(nextFrame()),
      ).objects.map((object) => object.key).toList();

      expect(await detect(), isEmpty);
      candidates = [laptop, cup];
      expect(await detect(), [ObjectKey.laptop]);
      candidates = [laptop, bottle, cup];
      expect(await detect(), [
        ObjectKey.laptop,
        ObjectKey.cup,
        ObjectKey.bottle,
      ]);
      candidates = [laptop, cup];
      expect(await detect(), [ObjectKey.laptop, ObjectKey.cup]);
      expect(await detect(), [ObjectKey.laptop, ObjectKey.cup]);
      candidates = [laptop, bottle, cup];
      expect(await detect(), [ObjectKey.laptop, ObjectKey.cup]);
    },
  );

  test(
    'an unmatched, low-confidence or failed frame breaks a search streak',
    () async {
      final bottle = _candidate('bottle', .8, .10, .30);
      var candidates = [bottle];
      var failInference = false;
      messenger.setMockMethodCallHandler(channel, (_) async {
        if (failInference) throw PlatformException(code: 'inference_failed');
        return candidates;
      });
      final detector = MediaPipeObjectDetector(channel: channel);
      addTearDown(detector.dispose);
      Future<DetectionResult> findBottle() async => _success(
        await detector.detect(nextFrame(), targetKey: ObjectKey.bottle),
      );

      for (final absent in [
        [_candidate('book', .9, .10, .30)],
        [_candidate('bottle', .49, .10, .30)],
      ]) {
        candidates = [bottle];
        expect((await findBottle()).readiness, DetectionReadiness.stabilizing);
        expect((await findBottle()).readiness, DetectionReadiness.stabilizing);
        candidates = absent;
        expect((await findBottle()).readiness, DetectionReadiness.noMatch);
      }
      candidates = [bottle];
      await findBottle();
      await findBottle();
      failInference = true;
      final failure = await detector.detect(
        nextFrame(),
        targetKey: ObjectKey.bottle,
      );
      expect(failure.getLeft().toNullable(), isA<InferenceFailure>());
      failInference = false;
      expect((await findBottle()).objects, isEmpty);
      expect((await findBottle()).objects, isEmpty);
      expect((await findBottle()).objects.single.key, ObjectKey.bottle);
    },
  );

  test(
    'resets on camera session, logical request, target and rotation changes',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => [_candidate('bottle', .8, .2, .4)],
      );
      final detector = MediaPipeObjectDetector(channel: channel);
      addTearDown(detector.dispose);
      final request = Object();
      final nextRequest = Object();
      for (final (camera, rotation, epoch, target) in [
        ('camera-a', 0, request, null),
        ('camera-b', 0, request, null),
        ('camera-b', 0, nextRequest, null),
        ('camera-b', 0, nextRequest, ObjectKey.bottle),
        ('camera-b', 180, nextRequest, ObjectKey.bottle),
        ('camera-b', 270, nextRequest, ObjectKey.bottle),
      ]) {
        final first = nextFrame(sessionId: camera, rotation: rotation);
        for (final input in [
          first,
          first,
          nextFrame(sessionId: camera, rotation: rotation),
        ]) {
          final result = await detector.detect(
            input,
            targetKey: target,
            requestSession: epoch,
          );
          final expected = target == null && !identical(input, first)
              ? DetectionReadiness.stable
              : DetectionReadiness.stabilizing;
          expect(_success(result).readiness, expected);
        }
      }
    },
  );

  test(
    'requires repeated observations in a new zone after boundary jitter',
    () async {
      var left = .22;
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => [_candidate('bottle', .8, left, left + .20)],
      );
      final detector = MediaPipeObjectDetector(channel: channel);
      addTearDown(detector.dispose);
      Future<DetectionResult> detect() async =>
          _success(await detector.detect(nextFrame()));

      await detect();
      expect((await detect()).objects.single.zone, HorizontalZone.left);
      left = .24;
      expect((await detect()).objects, isEmpty);
      left = .22;
      expect((await detect()).objects, isEmpty);
      left = .24;
      expect((await detect()).objects, isEmpty);
      expect((await detect()).objects.single.zone, HorizontalZone.center);
    },
  );

  test(
    'unsupported targets and unavailable model are typed outcomes',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'dispose') return null;
        calls++;
        throw PlatformException(code: 'model_unavailable');
      });
      final detector = MediaPipeObjectDetector(channel: channel);
      addTearDown(detector.dispose);

      final unsupported = await detector.detect(
        frame,
        targetKey: ObjectKey.keys,
      );
      expect(
        unsupported.getLeft().toNullable(),
        isA<UnsupportedDetectionTargetFailure>(),
      );
      expect(calls, 0);
      final unavailable = await detector.detect(frame);
      expect(unavailable.getLeft().toNullable(), isA<ModelNotLoadedFailure>());
      await detector.detect(frame);
      expect(calls, 1);
    },
  );
}

DetectionResult _success(Either<DetectionFailure, DetectionResult> outcome) =>
    outcome.match(
      (failure) => fail('Unexpected failure: $failure'),
      (result) => result,
    );

Map<String, Object> _candidate(
  String label,
  double score,
  double left,
  double right,
) => {
  'label': label,
  'score': score,
  'left': left,
  'top': 0.2,
  'right': right,
  'bottom': 0.7,
};
