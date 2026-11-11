import '../voice_command_contract.dart';

/// In-memory fake implementation of [VoiceCommandContract] for tests.
class FakeVoiceCommandService implements VoiceCommandContract {
  FakeVoiceCommandService({this.offlineAvailable = true, this.defaultResult});

  bool offlineAvailable;
  CommandResult? defaultResult;
  final List<CommandResult> queuedResults = [];

  bool isListening = false;
  bool isDisposed = false;

  void enqueueResult(CommandResult result) {
    queuedResults.add(result);
  }

  @override
  Future<bool> isOfflineAvailable() async => offlineAvailable;

  @override
  Future<CommandResult> listenForCommand({
    Duration timeout = const Duration(seconds: 5),
    void Function()? onListening,
  }) async {
    isListening = true;
    try {
      onListening?.call();
      if (queuedResults.isNotEmpty) {
        return queuedResults.removeAt(0);
      }
      return defaultResult ??
          const CommandResult(
            isUnderstood: true,
            isSupported: true,
            action: AssistanceAction.findObject,
          );
    } finally {
      isListening = false;
    }
  }

  @override
  Future<void> stopListening() async {
    isListening = false;
  }

  @override
  void dispose() {
    isDisposed = true;
  }
}
