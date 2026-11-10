/// Domain contracts for parsed voice commands.
library;

// ---------------------------------------------------------------------------
// VoiceAction
// ---------------------------------------------------------------------------

enum VoiceAction {
  detectObjects,
  readText,
  stopReading,
  findObject,
}

// ---------------------------------------------------------------------------
// SupportedObject
// ---------------------------------------------------------------------------

enum SupportedObject {
  wallet,
  keys,
  phone,
  bottle,
  cup,
  book,
  bag,
  chair,
  person,
}

// ---------------------------------------------------------------------------
// ParsedCommand sealed hierarchy
// ---------------------------------------------------------------------------

sealed class ParsedCommand {
  const ParsedCommand();
}

/// Input was empty or whitespace only.
final class EmptyCommand extends ParsedCommand {
  const EmptyCommand();

  @override
  String toString() => 'EmptyCommand()';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is EmptyCommand;

  @override
  int get hashCode => 0;
}

/// A known voice action was identified.
final class RecognizedCommand extends ParsedCommand {
  const RecognizedCommand({
    required this.action,
    this.targetObject,
  });

  final VoiceAction action;

  /// Non-null only when [action] is [VoiceAction.findObject].
  final SupportedObject? targetObject;

  @override
  String toString() =>
      'RecognizedCommand(action: $action, targetObject: $targetObject)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecognizedCommand &&
          action == other.action &&
          targetObject == other.targetObject;

  @override
  int get hashCode => Object.hash(action, targetObject);
}

/// The user asked to find an object that the app does not support.
final class UnsupportedObjectCommand extends ParsedCommand {
  const UnsupportedObjectCommand({required this.requestedObjectName});

  final String requestedObjectName;

  @override
  String toString() =>
      'UnsupportedObjectCommand(requestedObjectName: $requestedObjectName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnsupportedObjectCommand &&
          requestedObjectName == other.requestedObjectName;

  @override
  int get hashCode => requestedObjectName.hashCode;
}

/// The transcript did not match any known command.
final class UnknownCommand extends ParsedCommand {
  const UnknownCommand({required this.transcript});

  final String transcript;

  @override
  String toString() => 'UnknownCommand(transcript: $transcript)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnknownCommand && transcript == other.transcript;

  @override
  int get hashCode => transcript.hashCode;
}

// ---------------------------------------------------------------------------
// STT Engine Contract
// ---------------------------------------------------------------------------

/// Speech-to-Text availability state.
enum SttAvailability {
  available,
  vietnameseNotSupported,
  offlineNotSupported,
  permissionDenied,
  notAvailable,
}

/// Abstract STT engine interface for short command recognition sessions.
abstract interface class SttEngine {
  /// Checks availability on the current device.
  Future<SttAvailability> checkAvailability();

  /// Starts listening for a single user-initiated voice command.
  Future<bool> startListening({
    required void Function(String partial) onPartial,
    required void Function(String finalResult) onFinal,
    required void Function(String error) onError,
    Duration timeout = const Duration(seconds: 8),
  });

  /// Stops the current listening session.
  Future<void> stopListening();

  /// Releases speech recognition resources.
  Future<void> dispose();
}
