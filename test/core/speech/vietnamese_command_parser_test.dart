import 'package:flutter_agentic_starter/core/speech/fake_stt_engine.dart';
import 'package:flutter_agentic_starter/core/speech/stt_engine.dart';
import 'package:flutter_agentic_starter/core/speech/vietnamese_command_parser.dart';
import 'package:flutter_agentic_starter/core/speech/voice_command_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VietnameseCommandParser', () {
    const parser = VietnameseCommandParser();

    group('Empty & whitespace inputs', () {
      test('empty string returns EmptyCommand', () {
        expect(parser.parse(''), isA<EmptyCommand>());
      });

      test('whitespace string returns EmptyCommand', () {
        expect(parser.parse('   \t \n  '), isA<EmptyCommand>());
      });
    });

    group('detectObjects commands', () {
      test('exact phrase "nhận diện đồ vật"', () {
        final result = parser.parse('nhận diện đồ vật');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.detectObjects));
        expect(result.targetObject, isNull);
      });

      test('alias "nhận diện"', () {
        final result = parser.parse('nhận diện');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.detectObjects));
      });

      test('alias "quét vật"', () {
        final result = parser.parse('quét vật');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.detectObjects));
      });

      test('casing and punctuation normalization', () {
        final result = parser.parse('  NHẬN DIỆN ĐỒ VẬT!  ');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.detectObjects));
      });
    });

    group('readText commands', () {
      test('alias "đọc văn bản"', () {
        final result = parser.parse('đọc văn bản');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.readText));
      });

      test('alias "đọc chữ"', () {
        final result = parser.parse('đọc chữ');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.readText));
      });

      test('alias "đọc nội dung"', () {
        final result = parser.parse('đọc nội dung');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.readText));
      });
    });

    group('stopReading commands', () {
      test('alias "dừng đọc"', () {
        final result = parser.parse('dừng đọc');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.stopReading));
      });

      test('alias "dừng lại"', () {
        final result = parser.parse('dừng lại');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.stopReading));
      });

      test('alias "thôi"', () {
        final result = parser.parse('thôi');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.stopReading));
      });

      test('alias "im lặng"', () {
        final result = parser.parse('im lặng');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.stopReading));
      });
    });

    group('findObject commands for supported vocabulary', () {
      test('tìm ví', () {
        final result = parser.parse('tìm ví');
        expect(result, isA<RecognizedCommand>());
        final cmd = result as RecognizedCommand;
        expect(cmd.action, equals(VoiceAction.findObject));
        expect(cmd.targetObject, equals(SupportedObject.wallet));
      });

      test('tìm chìa khóa', () {
        final result = parser.parse('tìm chìa khóa');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).targetObject, equals(SupportedObject.keys));
      });

      test('tìm chìa khoá (dấu xoay)', () {
        final result = parser.parse('tìm chìa khoá');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).targetObject, equals(SupportedObject.keys));
      });

      test('tìm điện thoại', () {
        final result = parser.parse('tìm điện thoại');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).targetObject, equals(SupportedObject.phone));
      });

      test('tìm chai nước', () {
        final result = parser.parse('tìm chai nước');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).targetObject, equals(SupportedObject.bottle));
      });

      test('tìm cái ly', () {
        final result = parser.parse('tìm cái ly');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).targetObject, equals(SupportedObject.cup));
      });

      test('tìm cuốn sách', () {
        final result = parser.parse('tìm cuốn sách');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).targetObject, equals(SupportedObject.book));
      });

      test('tìm ba lô', () {
        final result = parser.parse('tìm ba lô');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).targetObject, equals(SupportedObject.bag));
      });

      test('tìm ghế', () {
        final result = parser.parse('tìm ghế');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).targetObject, equals(SupportedObject.chair));
      });

      test('tìm người', () {
        final result = parser.parse('tìm người');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).targetObject, equals(SupportedObject.person));
      });

      test('prefix "tìm kiếm"', () {
        final result = parser.parse('tìm kiếm chìa khóa');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).targetObject, equals(SupportedObject.keys));
      });
    });

    group('UnsupportedObjectCommand', () {
      test('tìm xe máy returns UnsupportedObjectCommand', () {
        final result = parser.parse('tìm xe máy');
        expect(result, isA<UnsupportedObjectCommand>());
        expect((result as UnsupportedObjectCommand).requestedObjectName, equals('xe máy'));
      });

      test('tìm tivi returns UnsupportedObjectCommand', () {
        final result = parser.parse('tìm tivi');
        expect(result, isA<UnsupportedObjectCommand>());
        expect((result as UnsupportedObjectCommand).requestedObjectName, equals('tivi'));
      });
    });

    group('UnknownCommand', () {
      test('random phrase returns UnknownCommand', () {
        final result = parser.parse('hôm nay thời tiết đẹp quá');
        expect(result, isA<UnknownCommand>());
        expect((result as UnknownCommand).transcript, equals('hôm nay thời tiết đẹp quá'));
      });

      test('only prefix "tìm" without object returns UnknownCommand', () {
        final result = parser.parse('tìm');
        expect(result, isA<UnknownCommand>());
      });
    });
  });

  group('FakeSttEngine & VoiceCommandAdapter', () {
    test('FakeSttEngine dispatches partial, final, and error callbacks', () async {
      final engine = FakeSttEngine();
      expect(await engine.checkAvailability(), equals(SttAvailability.available));

      String? partialResult;
      String? finalResult;
      String? errorMessage;

      final started = await engine.startListening(
        onPartial: (p) => partialResult = p,
        onFinal: (f) => finalResult = f,
        onError: (e) => errorMessage = e,
      );
      expect(started, isTrue);
      expect(engine.isListening, isTrue);

      engine.deliverPartial('đang');
      expect(partialResult, equals('đang'));

      engine.deliverFinal('đọc văn bản');
      expect(finalResult, equals('đọc văn bản'));
      expect(engine.isListening, isFalse);

      // Test error path
      await engine.startListening(
        onPartial: (_) {},
        onFinal: (_) {},
        onError: (e) => errorMessage = e,
      );
      engine.deliverError('Mic error');
      expect(errorMessage, equals('Mic error'));

      await engine.dispose();
      expect(engine.isDisposed, isTrue);
    });

    test('VoiceCommandAdapter reports notAvailable when uninitialized', () async {
      final adapter = VoiceCommandAdapter();
      expect(await adapter.checkAvailability(), equals(SttAvailability.notAvailable));
      final started = await adapter.startListening(
        onPartial: (_) {},
        onFinal: (_) {},
        onError: (_) {},
      );
      expect(started, isFalse);
      await adapter.dispose();
    });
  });
}
