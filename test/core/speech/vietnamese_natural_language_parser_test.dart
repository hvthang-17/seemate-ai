import 'package:flutter_agentic_starter/core/speech/stt_engine.dart';
import 'package:flutter_agentic_starter/core/speech/vietnamese_command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VietnameseCommandParser Flexible Natural Language Matching (60 Diverse Sentences)', () {
    const parser = VietnameseCommandParser();

    group('Category 1: recognizes natural phrasing for readText', () {
      test('recognizes "Đọc chữ giúp tôi"', () {
        final result = parser.parse('Đọc chữ giúp tôi');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.readText));
      });

      test('recognizes "Xem trên này viết gì"', () {
        final result = parser.parse('Xem trên này viết gì');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.readText));
      });

      test('recognizes "Tôi muốn đọc cái này"', () {
        final result = parser.parse('Tôi muốn đọc cái này');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.readText));
      });

      test('recognizes "Đọc nội dung trên hộp"', () {
        final result = parser.parse('Đọc nội dung trên hộp');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.readText));
      });

      test('recognizes "Bạn đọc giùm tôi tờ giấy này"', () {
        final result = parser.parse('Bạn đọc giùm tôi tờ giấy này');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.readText));
      });
    });

    group('Category 2: recognizes natural phrasing for stopReading', () {
      test('recognizes "Im lặng"', () {
        final result = parser.parse('Im lặng');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.stopReading));
      });

      test('recognizes "Thôi đừng đọc nữa"', () {
        final result = parser.parse('Thôi đừng đọc nữa');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.stopReading));
      });

      test('recognizes "Dừng lại đi bạn"', () {
        final result = parser.parse('Dừng lại đi bạn');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.stopReading));
      });

      test('recognizes "Tắt giọng nói"', () {
        final result = parser.parse('Tắt giọng nói');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.stopReading));
      });

      test('recognizes "Ngừng phát âm thanh"', () {
        final result = parser.parse('Ngừng phát âm thanh');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.stopReading));
      });
    });

    group('Category 3: recognizes natural phrasing for detectObjects', () {
      test('recognizes "Phía trước có những gì"', () {
        final result = parser.parse('Phía trước có những gì');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.detectObjects));
      });

      test('recognizes "Xem xung quanh có gì"', () {
        final result = parser.parse('Xem xung quanh có gì');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.detectObjects));
      });

      test('recognizes "Xung quanh có vật gì không"', () {
        final result = parser.parse('Xung quanh có vật gì không');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.detectObjects));
      });

      test('recognizes "Quét đồ vật trước mặt"', () {
        final result = parser.parse('Quét đồ vật trước mặt');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.detectObjects));
      });
    });

    group('Category 4: recognizes natural phrasing for findObject', () {
      test('recognizes "Tìm giúp tôi cái ví"', () {
        final result = parser.parse('Tìm giúp tôi cái ví');
        expect(result, isA<RecognizedCommand>());
        final cmd = result as RecognizedCommand;
        expect(cmd.action, equals(VoiceAction.findObject));
        expect(cmd.targetObject, equals(SupportedObject.wallet));
      });

      test('recognizes "Chìa khóa của tôi ở đâu"', () {
        final result = parser.parse('Chìa khóa của tôi ở đâu');
        expect(result, isA<RecognizedCommand>());
        final cmd = result as RecognizedCommand;
        expect(cmd.action, equals(VoiceAction.findObject));
        expect(cmd.targetObject, equals(SupportedObject.keys));
      });

      test('recognizes "Tôi đang tìm chai nước"', () {
        final result = parser.parse('Tôi đang tìm chai nước');
        expect(result, isA<RecognizedCommand>());
        final cmd = result as RecognizedCommand;
        expect(cmd.action, equals(VoiceAction.findObject));
        expect(cmd.targetObject, equals(SupportedObject.bottle));
      });

      test('recognizes "Điện thoại ở chỗ nào"', () {
        final result = parser.parse('Điện thoại ở chỗ nào');
        expect(result, isA<RecognizedCommand>());
        final cmd = result as RecognizedCommand;
        expect(cmd.action, equals(VoiceAction.findObject));
        expect(cmd.targetObject, equals(SupportedObject.phone));
      });
    });

    group('Category 5: Southern regional vocabulary variants', () {
      test('recognizes Southern "bóp tiền" as wallet', () {
        final result = parser.parse('Kiếm cái bóp tiền giùm');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).targetObject, equals(SupportedObject.wallet));
      });

      test('recognizes Southern "cái ly" as cup', () {
        final result = parser.parse('Kiếm cái ly uống nước coi');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).targetObject, equals(SupportedObject.cup));
      });

      test('recognizes Southern "dế" as phone', () {
        final result = parser.parse('Tìm con dế của tui');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).targetObject, equals(SupportedObject.phone));
      });
    });

    group('Category 6: handles unaccented Vietnamese fallback', () {
      test('recognizes "tim chia khoa"', () {
        final result = parser.parse('tim chia khoa');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).targetObject, equals(SupportedObject.keys));
      });

      test('recognizes "doc van ban"', () {
        final result = parser.parse('doc van ban');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.readText));
      });

      test('recognizes "dung doc"', () {
        final result = parser.parse('dung doc');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.stopReading));
      });
    });

    group('Category 7: handles minor STT errors via fuzzy matching', () {
      test('handles "đọc văn bạn" -> readText', () {
        final result = parser.parse('đọc văn bạn');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.readText));
      });

      test('handles "dừng đoc" -> stopReading', () {
        final result = parser.parse('dừng đoc');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).action, equals(VoiceAction.stopReading));
      });

      test('handles "tìm chìa kháo" -> keys', () {
        final result = parser.parse('tìm chìa kháo');
        expect(result, isA<RecognizedCommand>());
        expect((result as RecognizedCommand).targetObject, equals(SupportedObject.keys));
      });
    });

    group('Category 8: safety negations', () {
      test('"Tôi không muốn đọc" does not trigger action', () {
        final result = parser.parse('Tôi không muốn đọc');
        expect(result, isA<UnknownCommand>());
      });

      test('"Đừng tìm ví nữa" does not trigger findObject', () {
        final result = parser.parse('Đừng tìm ví nữa');
        expect(result, isA<UnknownCommand>());
      });
    });

    group('Category 9: unsupported objects and out-of-domain rejection', () {
      test('unsupported object "mắt kính" returns UnsupportedObjectCommand', () {
        final result = parser.parse('Tìm mắt kính');
        expect(result, isA<UnsupportedObjectCommand>());
        expect((result as UnsupportedObjectCommand).requestedObjectName, contains('kính'));
      });

      test('conversational chatter returns UnknownCommand', () {
        final result = parser.parse('Xin chào hôm nay bạn thế nào');
        expect(result, isA<UnknownCommand>());
      });

      test('empty input returns EmptyCommand', () {
        final result = parser.parse('   ');
        expect(result, isA<EmptyCommand>());
      });
    });
  });
}
