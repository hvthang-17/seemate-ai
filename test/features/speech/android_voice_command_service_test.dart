import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_agentic_starter/features/speech/data/android_voice_command_service.dart';
import 'package:flutter_agentic_starter/shared/assistance_contracts/voice_command_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('seemate/test_voice_commands');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AndroidVoiceCommandService service;

  setUp(() => service = AndroidVoiceCommandService(channel: channel));
  tearDown(() {
    service.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('parses a transcript received from the local engine', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'isOfflineAvailable' => true,
        'listen' => {'status': 'recognized', 'text': 'chụp'},
        _ => null,
      };
    });
    expect(await service.isOfflineAvailable(), isTrue);
    expect(
      (await service.listenForCommand()).action,
      AssistanceAction.captureText,
    );
  });

  test('rejects recognized text outside the command vocabulary', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'listen') return null;
      return {'status': 'recognized', 'text': 'hôm nay trời đẹp'};
    });
    final result = await service.listenForCommand();
    expect(result.action, isNull);
    expect(result.action, isNull);
  });

  test('discards a recognized command received after stop', () async {
    final reply = Completer<Map<String, Object>>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'listen') return reply.future;
      return null;
    });
    final listening = service.listenForCommand();
    await service.stopListening();
    reply.complete({'status': 'recognized', 'text': 'chụp'});
    final result = await listening;
    expect(result.failure, VoiceCommandFailure.cancelled);
    expect(result.action, isNull);
  });

  test('reports a missing model and denied microphone separately', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'isOfflineAvailable' => false,
        'listen' => {'status': 'permission_denied'},
        _ => null,
      };
    });
    expect(await service.isOfflineAvailable(), isFalse);
    expect(
      (await service.listenForCommand()).failure,
      VoiceCommandFailure.permissionDenied,
    );
  });
}
