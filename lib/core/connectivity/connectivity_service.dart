import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Wraps [Connectivity] and exposes simplified online/offline updates.
///
/// Note: connectivity_plus reports network interface availability, not actual
/// internet reachability. For production apps, combine with an HTTP head-check.
///
/// Registered via [RegisterModule] in get_it.dart (not annotated) to avoid
/// injectable trying to inject the optional [Connectivity] typed parameter.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final _onlineController = StreamController<bool>.broadcast(sync: true);
  var _online = true;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Stream<bool> get onlineChanges => _onlineController.stream;

  bool get isOnline => _online;

  bool get isOffline => !_online;

  /// Start listening. Call once during app initialisation.
  Future<void> init() async {
    // Seed with current state.
    final results = await _connectivity.checkConnectivity();
    _setOnline(_resultsToOnline(results));

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = _resultsToOnline(results);
      _setOnline(online);
    });
  }

  /// Performs an on-demand connectivity check and updates [online].
  Future<bool> checkNow() async {
    final results = await _connectivity.checkConnectivity();
    _setOnline(_resultsToOnline(results));
    return _online;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _onlineController.close();
  }

  static bool _resultsToOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  void _setOnline(bool online) {
    if (online == _online) return;
    _online = online;
    _onlineController.add(online);
  }
}
