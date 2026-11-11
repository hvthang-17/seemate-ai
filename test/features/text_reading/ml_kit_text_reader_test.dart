import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_agentic_starter/features/text_reading/data/ml_kit_text_reader.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/assistance_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('seemate/test_text_recognition');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MlKitTextReader reader;

  setUp(() => reader = MlKitTextReader(channel: channel));
  tearDown(() {
    reader.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'forwards rotation and strides and returns Vietnamese text in order',
    () async {
      const lines = ['Cà phê sữa đá', 'Điện thoại để bên trái.'];
      final frame = _frame();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'dispose') return null;
        expect(call.method, 'read');
        expect(call.arguments, {
          'width': 4,
          'height': 2,
          'rotation': 270,
          'planes': [
            {'bytes': frame.planes[0].bytes, 'rowStride': 6, 'pixelStride': 1},
            {'bytes': frame.planes[1].bytes, 'rowStride': 4, 'pixelStride': 2},
            {'bytes': frame.planes[2].bytes, 'rowStride': 4, 'pixelStride': 2},
          ],
        });
        return {'text': lines.join('\n'), 'lines': lines};
      });

      final result = (await reader.readText(frame)).getRight().toNullable()!;
      expect(result.fullText, lines.join('\n'));
      expect(result.spans.map((span) => span.text), lines);
      expect(frame.isReleased, isFalse);
    },
  );

  test('preserves a successful no-text result', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'text': '', 'lines': <String>[]},
    );

    final result = (await reader.readText(_frame())).getRight().toNullable()!;
    expect(result.isEmpty, isTrue);
    expect(result.spans, isEmpty);
  });

  test(
    'rejects empty, invalid and pre-cancelled frames before platform call',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'dispose') fail('Unexpected platform call');
        return null;
      });
      final released = _frame()..release();
      expect(
        (await reader.readText(released)).getLeft().toNullable(),
        isA<EmptyImageFailure>(),
      );
      expect(
        (await reader.readText(_frame(rotation: 45))).getLeft().toNullable(),
        isA<OcrProcessingFailure>(),
      );
      final token = CancellationToken()..cancel();
      expect(
        (await reader.readText(
          _frame(),
          cancelToken: token,
        )).getLeft().toNullable(),
        isA<OcrCancelledFailure>(),
      );
    },
  );

  test(
    'cancellation wins over a late platform failure and rejects parallel work',
    () async {
      final response = Completer<Object?>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'dispose') return null;
        return response.future;
      });
      final token = CancellationToken();
      final request = reader.readText(_frame(), cancelToken: token);
      expect(
        (await reader.readText(_frame())).getLeft().toNullable(),
        isA<OcrProcessingFailure>(),
      );
      token.cancel();
      response.completeError(PlatformException(code: 'ocr_failed'));
      expect(
        (await request).getLeft().toNullable(),
        isA<OcrCancelledFailure>(),
      );
    },
  );

  test(
    'dispose releases native resources and discards the late text',
    () async {
      final response = Completer<Object?>();
      final disposeCall = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'dispose') {
          disposeCall.complete();
          return null;
        }
        return response.future;
      });
      final request = reader.readText(_frame());
      reader.dispose();
      await disposeCall.future;
      response.complete({
        'text': 'Đọc thử',
        'lines': ['Đọc thử'],
      });
      expect((await request).getLeft().toNullable(), isA<OcrDisposedFailure>());
      expect(
        (await reader.readText(_frame())).getLeft().toNullable(),
        isA<OcrDisposedFailure>(),
      );
    },
  );

  test(
    'returns typed processing failure without exposing platform details',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'dispose') return null;
        throw PlatformException(
          code: 'ocr_failed',
          message: 'Untrusted detail',
        );
      });
      final failure = (await reader.readText(_frame())).getLeft().toNullable();
      expect(
        failure,
        isA<OcrProcessingFailure>().having(
          (value) => value.message,
          'message',
          'Android text recognition failed',
        ),
      );
    },
  );
}

CameraFrame _frame({int rotation = 270}) => createFakeCameraFrame(
  width: 4,
  height: 2,
  rotationDegrees: rotation,
  planes: [
    FramePlane(bytes: Uint8List(12), bytesPerRow: 6, bytesPerPixel: 1),
    FramePlane(bytes: Uint8List(4), bytesPerRow: 4, bytesPerPixel: 2),
    FramePlane(bytes: Uint8List(4), bytesPerRow: 4, bytesPerPixel: 2),
  ],
);
