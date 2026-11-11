import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../shared/assistance_contracts/assistance_contracts.dart';
import '../permissions/permission_service.dart';

/// Adapter interface for low-level camera driver / platform channel.
abstract interface class CameraDriverAdapter {
  Future<bool> initializeCamera();
  Future<void> startFrameStream(
    String sessionId,
    void Function(CameraFrame frame) onFrame,
  );
  Future<void> stopFrameStream();
  Future<void> closeCamera();
}

/// In-memory fake driver for testing camera session lifecycle without hardware.
class FakeCameraDriverAdapter implements CameraDriverAdapter {
  FakeCameraDriverAdapter({this.failOnInitialize = false});

  bool failOnInitialize;
  bool isStreaming = false;
  bool isClosed = false;
  void Function(CameraFrame frame)? frameListener;
  String? _sessionId;

  @override
  Future<bool> initializeCamera() async {
    if (failOnInitialize) return false;
    isClosed = false;
    return true;
  }

  @override
  Future<void> startFrameStream(
    String sessionId,
    void Function(CameraFrame frame) onFrame,
  ) async {
    isStreaming = true;
    frameListener = onFrame;
    _sessionId = sessionId;
  }

  @override
  Future<void> stopFrameStream() async {
    isStreaming = false;
    frameListener = null;
  }

  @override
  Future<void> closeCamera() async {
    isStreaming = false;
    isClosed = true;
    frameListener = null;
  }

  void emitSyntheticFrame([CameraFrame? frame]) {
    if (isStreaming && frameListener != null) {
      frameListener!(frame ?? createFakeCameraFrame(sessionId: _sessionId!));
    } else {
      frame?.release();
    }
  }
}

/// Coordinates camera permission, session ownership, frame streaming, and backlog prevention.
class CameraSessionController {
  CameraSessionController({
    required PermissionService permissionService,
    CameraDriverAdapter? driverAdapter,
    Future<void> Function(CameraFrame frame)? onFrame,
  }) : _permissionService = permissionService,
       _driver = driverAdapter ?? FakeCameraDriverAdapter(),
       _onFrame = onFrame;

  final PermissionService _permissionService;
  final CameraDriverAdapter _driver;
  final Future<void> Function(CameraFrame frame)? _onFrame;

  final _statusController = StreamController<CameraSessionStatus>.broadcast();

  CameraSessionStatus _status = CameraSessionStatus.idle;
  CameraSessionFailure? _failure;
  int _activeSessionCount = 0;
  String? _currentSessionId;
  bool _isDisposed = false;
  var _sessionRequest = Object();
  Future<void> _driverOperation = Future<void>.value();
  Completer<CameraFrame?>? _capture;

  bool _hasFrameInFlight = false;

  CameraSessionStatus get status => _status;
  CameraSessionFailure? get failure => _failure;
  Stream<CameraSessionStatus> get statusStream => _statusController.stream;
  String? get currentSessionId => _currentSessionId;
  bool get isDisposed => _isDisposed;

  /// Captures one in-memory frame while previewing. No still file is created.
  Future<CameraFrame?> capturePreviewFrame() {
    if (_status != CameraSessionStatus.previewing || _capture != null) {
      return Future.value();
    }
    final request = _sessionRequest;
    final capture = _capture = Completer<CameraFrame?>();
    return _runDriverOperation(() async {
      CameraFrame? frame;
      try {
        if (capture.isCompleted || !identical(request, _sessionRequest)) {
          return null;
        }
        final id = 'capture-${++_activeSessionCount}';
        try {
          await _driver.startFrameStream(id, (candidate) {
            if (capture.isCompleted || candidate.sessionId != id) {
              candidate.release();
            } else {
              capture.complete(candidate);
            }
          });
          frame = await capture.future.timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              cancelCapture();
              return null;
            },
          );
        } finally {
          // Keep the preview open while stopping the temporary image stream.
          cancelCapture();
          frame ??= await capture.future;
          await _driver.stopFrameStream();
        }
        if (identical(request, _sessionRequest)) return frame;
      } on Exception {
        // The caller presents capture failure and can retry.
      } finally {
        _capture = null;
      }
      frame?.release();
      return null;
    });
  }

  void cancelCapture() {
    final capture = _capture;
    if (capture != null && !capture.isCompleted) capture.complete(null);
  }

  void _updateStatus(
    CameraSessionStatus newStatus, {
    CameraSessionFailure? failure,
  }) {
    _status = newStatus;
    _failure = failure;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  /// Requests permission if needed and starts the camera session.
  Future<Either<CameraSessionFailure, void>> startSession({
    bool requestPermission = true,
    bool analyzeFrames = true,
  }) {
    final request = _sessionRequest;
    return _runDriverOperation(
      () => _startSession(request, requestPermission, analyzeFrames),
    );
  }

  Future<T> _runDriverOperation<T>(Future<T> Function() action) {
    final operation = _driverOperation.then((_) => action());
    _driverOperation = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  Future<Either<CameraSessionFailure, void>> _startSession(
    Object request,
    bool requestPermission,
    bool analyzeFrames,
  ) async {
    if (_isDisposed) {
      return const Left(CameraDisposedFailure());
    }

    if (!identical(request, _sessionRequest)) {
      return const Left(CameraSessionCancelledFailure());
    }

    if (_status == CameraSessionStatus.streaming ||
        _status == CameraSessionStatus.previewing) {
      // Already running session
      return const Right(null);
    }

    _updateStatus(CameraSessionStatus.initializing);

    try {
      return await _openCamera(request, requestPermission, analyzeFrames);
    } on Exception {
      if (!identical(request, _sessionRequest)) {
        return const Left(CameraSessionCancelledFailure());
      }
      _currentSessionId = null;
      try {
        await _closeDriver();
      } on Exception {
        return _fail(
          CameraSessionStatus.error,
          const CameraStreamingFailure('Could not close camera'),
        );
      }
      if (!identical(request, _sessionRequest)) {
        return const Left(CameraSessionCancelledFailure());
      }
      return _fail(
        CameraSessionStatus.error,
        const CameraStreamingFailure('Could not start camera'),
      );
    }
  }

  Either<CameraSessionFailure, void> _fail(
    CameraSessionStatus status,
    CameraSessionFailure failure,
  ) {
    _updateStatus(status, failure: failure);
    return Left(failure);
  }

  Future<Either<CameraSessionFailure, void>> _openCamera(
    Object request,
    bool requestPermission,
    bool analyzeFrames,
  ) async {
    var permStatus = await _permissionService.check(AppPermission.camera);
    if (!identical(request, _sessionRequest)) {
      return const Left(CameraSessionCancelledFailure());
    }
    if (requestPermission && permStatus == AppPermissionStatus.denied) {
      permStatus = await _permissionService.request(AppPermission.camera);
    }
    if (!identical(request, _sessionRequest)) {
      return const Left(CameraSessionCancelledFailure());
    }

    if (permStatus != AppPermissionStatus.granted) {
      return _fail(
        CameraSessionStatus.permissionDenied,
        CameraPermissionDeniedFailure(
          isPermanentlyDenied:
              permStatus == AppPermissionStatus.permanentlyDenied,
        ),
      );
    }

    // 2. Initialize driver
    final initOk = await _driver.initializeCamera();
    if (!identical(request, _sessionRequest)) {
      return const Left(CameraSessionCancelledFailure());
    }
    if (!initOk) {
      return _fail(CameraSessionStatus.error, const CameraNotFoundFailure());
    }

    if (_onFrame == null || !analyzeFrames) {
      _updateStatus(CameraSessionStatus.previewing);
      return const Right(null);
    }

    // 3. Start unique session
    _activeSessionCount++;
    final sessionId =
        'session-$_activeSessionCount-${DateTime.now().millisecondsSinceEpoch}';
    _currentSessionId = sessionId;

    await _driver.startFrameStream(sessionId, (frame) {
      _handleIncomingFrame(frame, sessionId);
    });
    if (!identical(request, _sessionRequest)) {
      return const Left(CameraSessionCancelledFailure());
    }

    _updateStatus(CameraSessionStatus.streaming);
    return const Right(null);
  }

  void _handleIncomingFrame(CameraFrame frame, String boundSessionId) {
    final onFrame = _onFrame;
    if (_isDisposed ||
        onFrame == null ||
        _hasFrameInFlight ||
        frame.sessionId != boundSessionId ||
        boundSessionId != _currentSessionId ||
        _status != CameraSessionStatus.streaming) {
      frame.release();
      return;
    }

    _hasFrameInFlight = true;
    unawaited(_deliverFrame(frame, onFrame));
  }

  Future<void> _deliverFrame(
    CameraFrame frame,
    Future<void> Function(CameraFrame frame) onFrame,
  ) async {
    try {
      await onFrame(frame);
    } finally {
      frame.release();
      _hasFrameInFlight = false;
    }
  }

  /// Temporarily pauses streaming (e.g. during app backgrounding).
  Future<void> pauseSession() async {
    if (_isDisposed || _status == CameraSessionStatus.closed) return;
    await _suspendSession(CameraSessionStatus.paused);
  }

  /// Resumes from pause after returning to foreground.
  Future<Either<CameraSessionFailure, void>> resumeSession() async {
    if (_isDisposed || _status != CameraSessionStatus.paused) {
      return const Right(null);
    }
    return startSession(requestPermission: false);
  }

  /// Stops current camera session and closes driver.
  Future<void> stopSession() async {
    if (_isDisposed) return;
    await _suspendSession(CameraSessionStatus.closed);
  }

  Future<void> _suspendSession(CameraSessionStatus status) async {
    final request = _sessionRequest = Object();
    cancelCapture();
    _currentSessionId = null;
    _updateStatus(status);
    try {
      await _runDriverOperation(_closeDriver);
    } on Exception {
      if (!_isDisposed && identical(request, _sessionRequest)) {
        _updateStatus(
          CameraSessionStatus.error,
          failure: const CameraStreamingFailure('Could not close camera'),
        );
      }
    }
  }

  Future<void> _closeDriver() async {
    try {
      await _driver.stopFrameStream();
    } finally {
      await _driver.closeCamera();
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    try {
      await _suspendSession(CameraSessionStatus.closed);
    } finally {
      unawaited(_statusController.close());
    }
  }
}
