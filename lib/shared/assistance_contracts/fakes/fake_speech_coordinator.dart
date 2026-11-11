import 'dart:async';

import '../speech_coordinator_contract.dart';

/// In-memory fake implementation of [SpeechCoordinatorContract] with deterministic duplicate suppression.
class FakeSpeechCoordinator implements SpeechCoordinatorContract {
  FakeSpeechCoordinator({
    this.suppressionInterval = const Duration(seconds: 2),
    this.readiness = const VoiceReadiness(isAvailable: true, isOffline: true),
    DateTime Function()? nowProvider,
  }) : _nowProvider = nowProvider ?? DateTime.now;

  final DateTime Function() _nowProvider;
  Duration suppressionInterval;
  VoiceReadiness readiness;

  final List<String> spokenUtterances = [];
  final Map<SuppressionKey, DateTime> _lastSpokenTimes = {};
  final _stateController = StreamController<SpeechState>.broadcast();

  SpeechState _currentState = SpeechState.idle;
  double _speechRate = 1.0;
  bool _feedbackEnabled = true;
  bool isDisposed = false;
  int stopCallCount = 0;

  double get speechRate => _speechRate;

  @override
  SpeechState get currentState => _currentState;

  @override
  Stream<SpeechState> get stateChanges => _stateController.stream;

  @override
  Future<VoiceReadiness> checkVoiceReadiness() async => readiness;

  @override
  Future<bool> speak(
    String text, {
    SpeechPriority priority = SpeechPriority.normal,
    SuppressionKey? suppressionKey,
  }) async {
    if (isDisposed || (!_feedbackEnabled && suppressionKey != null)) return false;

    final now = _nowProvider();

    // Check duplicate suppression
    if (suppressionKey != null) {
      final lastSpoken = _lastSpokenTimes[suppressionKey];
      if (lastSpoken != null && now.difference(lastSpoken) < suppressionInterval) {
        // Suppressed duplicate
        return false;
      }
      _lastSpokenTimes[suppressionKey] = now;
    }

    _currentState = SpeechState.speaking;
    _stateController.add(SpeechState.speaking);
    spokenUtterances.add(text);

    return true;
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
    _currentState = SpeechState.stopped;
    _stateController.add(SpeechState.stopped);
    _currentState = SpeechState.idle;
    _stateController.add(SpeechState.idle);
  }

  @override
  void updateSuppressionInterval(Duration interval) {
    suppressionInterval = interval;
  }

  @override
  void setSpokenFeedbackEnabled(bool enabled) => _feedbackEnabled = enabled;

  @override
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
  }

  @override
  void dispose() {
    isDisposed = true;
    _stateController.close();
  }
}
