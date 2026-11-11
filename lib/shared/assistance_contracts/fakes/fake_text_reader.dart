import 'package:fpdart/fpdart.dart';

import '../frame_session_contract.dart';
import '../text_reader_contract.dart';

/// In-memory fake implementation of [TextReaderContract] for tests.
class FakeTextReader implements TextReaderContract {
  FakeTextReader({
    this.cannedResult = const OcrResult(fullText: 'Xin chào SeeMate AI'),
    this.failureToReturn,
    this.simulatedDelay = Duration.zero,
  });

  OcrResult cannedResult;
  OcrFailure? failureToReturn;
  Duration simulatedDelay;

  final List<CameraFrame> receivedFrames = [];
  bool isDisposed = false;

  @override
  Future<Either<OcrFailure, OcrResult>> readText(
    CameraFrame frame, {
    CancellationToken? cancelToken,
  }) async {
    if (isDisposed) {
      return const Left(OcrDisposedFailure());
    }

    receivedFrames.add(frame);

    if (simulatedDelay > Duration.zero) {
      await Future<void>.delayed(simulatedDelay);
    }

    if (cancelToken?.isCancelled ?? false) {
      return const Left(OcrCancelledFailure());
    }

    if (failureToReturn != null) {
      return Left(failureToReturn!);
    }

    return Right(cannedResult);
  }

  @override
  void dispose() {
    isDisposed = true;
  }
}
