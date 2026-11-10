import 'dart:async';

import 'package:flutter_agentic_starter/core/speech/fake_stt_engine.dart';
import 'package:flutter_agentic_starter/core/speech/fake_tts_engine.dart';
import 'package:flutter_agentic_starter/core/speech/speech_coordinator.dart';
import 'package:flutter_agentic_starter/core/speech/stt_engine.dart';
import 'package:flutter_agentic_starter/core/speech/vietnamese_command_parser.dart';
import 'package:flutter_agentic_starter/core/speech/voice_command_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceCommandCoordinator Integration & Natural Language Safety', () {
    late FakeTtsEngine fakeTts;
    late FakeSttEngine fakeStt;
    late SpeechCoordinator speechCoordinator;
    late VoiceCommandCoordinator coordinator;

    bool navigatedToOcr = false;
    bool navigatedToDetection = false;

    setUp(() {
      fakeTts = FakeTtsEngine();
      fakeStt = FakeSttEngine();
      speechCoordinator = SpeechCoordinator(engine: fakeTts);
      speechCoordinator.initialize();

      navigatedToOcr = false;
      navigatedToDetection = false;

      coordinator = VoiceCommandCoordinator(
        sttEngine: fakeStt,
        speechCoordinator: speechCoordinator,
        parser: const VietnameseCommandParser(),
        onNavigateToOcr: () => navigatedToOcr = true,
        onNavigateToDetection: () => navigatedToDetection = true,
      );
    });

    tearDown(() async {
      await coordinator.dispose();
      await speechCoordinator.dispose();
      await fakeStt.dispose();
      await fakeTts.dispose();
    });

    test('startListeningSession stops ongoing speech before opening microphone', () async {
      await speechCoordinator.speakDirect('Đang đọc đoạn văn bản dài...');
      expect(fakeTts.isSpeaking, isTrue);

      final started = await coordinator.startListeningSession();
      expect(started, isTrue);
      expect(fakeTts.stopCount, greaterThanOrEqualTo(1));
      expect(coordinator.status, equals(VoiceSessionStatus.listening));
    });

    test('partial transcription updates status but NEVER executes command actions', () async {
      await coordinator.startListeningSession();

      fakeStt.emitPartial('dừng');
      expect(coordinator.currentPartialText, equals('dừng'));
      expect(coordinator.lastFinalTranscript, isEmpty);
      expect(coordinator.lastParsedCommand, isNull);
      expect(navigatedToOcr, isFalse);
    });

    test('final natural "Thôi đừng đọc nữa" executes stop and speaks confirmation', () async {
      await coordinator.startListeningSession();
      final stopCountBefore = fakeTts.stopCount;

      fakeStt.emitFinal('Thôi đừng đọc nữa');
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.lastFinalTranscript, equals('Thôi đừng đọc nữa'));
      expect(
        coordinator.lastParsedCommand,
        equals(const RecognizedCommand(action: VoiceAction.stopReading)),
      );
      expect(fakeTts.stopCount, greaterThan(stopCountBefore));
      expect(fakeTts.spokenTexts.last, contains('Đã dừng đọc'));
      expect(coordinator.status, equals(VoiceSessionStatus.completed));
    });

    test('final natural "Xem trên này viết gì" speaks confirmation and opens OCR', () async {
      await coordinator.startListeningSession();

      fakeStt.emitFinal('Xem trên này viết gì');
      await Future<void>.delayed(Duration.zero);

      expect(navigatedToOcr, isTrue);
      expect(
        coordinator.lastParsedCommand,
        equals(const RecognizedCommand(action: VoiceAction.readText)),
      );
      expect(fakeTts.spokenTexts.last, contains('Đang mở chức năng đọc văn bản'));
    });

    test('final natural "Tìm cái ví giùm tôi" speaks confirmation and starts finding wallet', () async {
      await coordinator.startListeningSession();

      fakeStt.emitFinal('Tìm cái ví giùm tôi');
      await Future<void>.delayed(Duration.zero);

      expect(
        coordinator.lastParsedCommand,
        equals(
          const RecognizedCommand(
            action: VoiceAction.findObject,
            targetObject: SupportedObject.wallet,
          ),
        ),
      );
      expect(fakeTts.spokenTexts.last, contains('Bắt đầu tìm cái ví'));
    });

    test('handles unsupported object gracefully', () async {
      await coordinator.startListeningSession();

      fakeStt.emitFinal('Tìm mắt kính');
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.lastParsedCommand, isA<UnsupportedObjectCommand>());
      expect(fakeTts.spokenTexts.last, contains('chưa hỗ trợ tìm đồ vật'));
    });

    test('negated command acknowledged safely and does not trigger action', () async {
      await coordinator.startListeningSession();

      fakeStt.emitFinal('Đừng tìm ví nữa');
      await Future<void>.delayed(Duration.zero);

      // Maps to UnknownCommand to ensure no destructive or unexpected action runs
      expect(coordinator.lastParsedCommand, isA<UnknownCommand>());
      expect(navigatedToOcr, isFalse);
      expect(navigatedToDetection, isFalse);
    });

    test('handles microphone permission denied gracefully', () async {
      fakeStt.availability = SttAvailability.permissionDenied;

      final started = await coordinator.startListeningSession();
      expect(started, isFalse);
      expect(coordinator.status, equals(VoiceSessionStatus.error));
      expect(coordinator.statusMessage, contains('Microphone bị từ chối'));
    });

    test('canceling listening session resets status without executing commands', () async {
      await coordinator.startListeningSession();
      expect(coordinator.isListening, isTrue);

      await coordinator.cancelListeningSession();
      expect(coordinator.isListening, isFalse);
      expect(coordinator.status, equals(VoiceSessionStatus.idle));
      expect(coordinator.lastParsedCommand, isNull);
    });

    test('empty transcript resets session to idle', () async {
      await coordinator.startListeningSession();

      fakeStt.emitFinal('   ');
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.status, equals(VoiceSessionStatus.idle));
    });
  });
}
