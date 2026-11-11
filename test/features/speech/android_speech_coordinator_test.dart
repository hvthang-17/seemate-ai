import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_agentic_starter/features/speech/data/android_speech_coordinator.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/assistance_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SpeechPlatform platform;
  late AndroidSpeechCoordinator coordinator;
  late Duration now;

  const leftBottle = SuppressionKey(
    objectKey: ObjectKey.bottle,
    zone: HorizontalZone.left,
  );
  const centerBottle = SuppressionKey(
    objectKey: ObjectKey.bottle,
    zone: HorizontalZone.center,
  );

  setUp(() {
    now = Duration.zero;
    platform = _SpeechPlatform();
    coordinator = AndroidSpeechCoordinator(elapsed: () => now);
  });

  tearDown(() {
    coordinator.dispose();
    platform.close();
  });

  test(
    'readiness distinguishes a missing voice from a network voice',
    () async {
      var readiness = await coordinator.checkVoiceReadiness();
      expect(readiness.isAvailable, isFalse);
      expect(readiness.isOffline, isFalse);

      platform.readiness = {'available': true, 'offline': false};
      readiness = await coordinator.checkVoiceReadiness();
      expect(readiness.isAvailable, isTrue);
      expect(readiness.isOffline, isFalse);

      platform.readiness = {
        'available': true,
        'offline': true,
        'voiceName': 'Vietnamese local voice',
      };
      readiness = await coordinator.checkVoiceReadiness();
      expect(readiness.isOffline, isTrue);
      expect(readiness.locale, 'vi-VN');
      expect(readiness.voiceName, 'Vietnamese local voice');
    },
  );

  test(
    'suppresses a duplicate and accepts a zone change immediately',
    () async {
      final states = <SpeechState>[];
      final subscription = coordinator.stateChanges.listen(states.add);
      addTearDown(subscription.cancel);

      expect(
        await coordinator.speak('chai bên trái', suppressionKey: leftBottle),
        isTrue,
      );
      final first = platform.lastId;
      await platform.emit(first, 'speaking');
      await platform.emit(first, 'done');
      expect(states, [SpeechState.speaking, SpeechState.idle]);

      now += const Duration(seconds: 1);
      expect(
        await coordinator.speak('chai bên trái', suppressionKey: leftBottle),
        isFalse,
      );
      expect(
        await coordinator.speak('chai ở giữa', suppressionKey: centerBottle),
        isTrue,
      );
      await platform.emit(platform.lastId, 'done');

      now += const Duration(seconds: 1);
      expect(
        await coordinator.speak('chai bên trái', suppressionKey: leftBottle),
        isTrue,
      );
      expect(platform.utterances, [
        'chai bên trái',
        'chai ở giữa',
        'chai bên trái',
      ]);
    },
  );

  test(
    'stop clears active and latest queued requests and rejects old events',
    () async {
      await coordinator.speak('đang đọc');
      final first = platform.lastId;
      await platform.emit(first, 'speaking');
      final older = coordinator.speak('yêu cầu cũ');
      final latest = coordinator.speak('yêu cầu mới');
      expect(await older, isFalse);
      expect(platform.utterances, ['đang đọc']);

      await coordinator.stop();
      expect(await latest, isFalse);
      await platform.emit(first, 'done');
      await platform.emit(first, 'speaking');
      expect(coordinator.currentState, SpeechState.idle);
      expect(platform.utterances, ['đang đọc']);
      expect(
        platform.calls.where((call) => call.method == 'stop'),
        hasLength(1),
      );

      expect(await coordinator.speak('yêu cầu sau khi dừng'), isTrue);
      expect(platform.utterances.last, 'yêu cầu sau khi dừng');
    },
  );

  test('higher priority waits for stop and ignores late acceptance', () async {
    final delayedAcceptance = Completer<bool>();
    final delayedStop = Completer<void>();
    platform.speakResponse = delayedAcceptance.future;
    platform.stopResponse = delayedStop.future;

    final low = coordinator.speak('nhận diện', priority: SpeechPriority.low);
    final oldId = platform.lastId;
    final high = coordinator.speak('văn bản', priority: SpeechPriority.high);
    expect(await low, isFalse);
    expect(platform.utterances, ['nhận diện']);
    expect(coordinator.currentState, SpeechState.stopped);

    delayedAcceptance.complete(true);
    await platform.emit(oldId, 'speaking');
    expect(coordinator.currentState, SpeechState.stopped);
    platform.speakResponse = Future<bool>.value(true);
    delayedStop.complete();
    expect(await high, isTrue);
    expect(platform.utterances, ['nhận diện', 'văn bản']);

    await platform.emit(platform.lastId, 'speaking');
    await platform.emit(oldId, 'done');
    expect(coordinator.currentState, SpeechState.speaking);
  });

  test(
    'stop clears suppression and disabled feedback still allows reading',
    () async {
      expect(
        await coordinator.speak('chai', suppressionKey: leftBottle),
        isTrue,
      );
      await platform.emit(platform.lastId, 'speaking');
      await coordinator.stop();
      expect(
        await coordinator.speak('chai', suppressionKey: leftBottle),
        isTrue,
      );
      await platform.emit(platform.lastId, 'done');

      coordinator.setSpokenFeedbackEnabled(false);
      expect(
        await coordinator.speak('chai giữa', suppressionKey: centerBottle),
        isFalse,
      );
      await coordinator.setSpeechRate(1.25);
      expect(await coordinator.speak('đọc văn bản'), isTrue);
      expect(platform.calls.last.arguments, containsPair('rate', 1.25));
    },
  );

  test('dispose cancels a pending request and rejects future work', () async {
    expect(await coordinator.speak('đang đọc'), isTrue);
    final pending = coordinator.speak('đọc sau');
    coordinator.dispose();

    expect(await pending, isFalse);
    expect(await coordinator.speak('đọc tiếp'), isFalse);
    expect((await coordinator.checkVoiceReadiness()).isAvailable, isFalse);
    expect(
      platform.calls.where((call) => call.method == 'dispose'),
      hasLength(1),
    );
  });
}

final class _SpeechPlatform {
  _SpeechPlatform() {
    _messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (call.method == 'stop') {
        await stopResponse;
        return null;
      }
      return switch (call.method) {
        'checkVoiceReadiness' => readiness,
        'speak' => await speakResponse,
        _ => null,
      };
    });
  }

  static const _channel = MethodChannel('seemate/speech');
  final _messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  Map<String, Object?> readiness = {'available': false, 'offline': false};
  Future<bool> speakResponse = Future<bool>.value(true);
  Future<void> stopResponse = Future<void>.value();

  Iterable<MethodCall> get _speakCalls =>
      calls.where((call) => call.method == 'speak');

  String get lastId => _speechArguments(_speakCalls.last)['id'] as String;

  List<String> get utterances => [
    for (final call in _speakCalls) _speechArguments(call)['text'] as String,
  ];

  Map<Object?, Object?> _speechArguments(MethodCall call) =>
      call.arguments as Map<Object?, Object?>;

  Future<void> emit(String id, String state) async {
    await _messenger.handlePlatformMessage(
      _channel.name,
      _channel.codec.encodeMethodCall(
        MethodCall('utteranceEvent', {'id': id, 'state': state}),
      ),
      null,
    );
  }

  void close() => _messenger.setMockMethodCallHandler(_channel, null);
}
