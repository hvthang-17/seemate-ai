import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';

import 'permission_service.dart';

/// Permission state with app-resume rechecks.
@injectable
final class PermissionViewModel with WidgetsBindingObserver {
  PermissionViewModel(this._service) {
    WidgetsBinding.instance.addObserver(this);
  }

  final PermissionService _service;
  var _statuses = const <AppPermission, AppPermissionStatus>{};

  Map<AppPermission, AppPermissionStatus> get statuses => _statuses;

  Future<AppPermissionStatus> checkAndRequest(AppPermission permission) async {
    var status = await _service.check(permission);
    if (status == AppPermissionStatus.denied) {
      status = await _service.request(permission);
    }
    _statuses = {..._statuses, permission: status};
    return status;
  }

  Future<void> recheckAll() async {
    final current = _statuses;
    if (current.isEmpty) return;

    final updated = Map<AppPermission, AppPermissionStatus>.from(current);
    for (final permission in current.keys) {
      updated[permission] = await _service.check(permission);
    }
    _statuses = updated;
  }

  bool isGranted(AppPermission permission) {
    final status = _statuses[permission];
    return status == AppPermissionStatus.granted ||
        status == AppPermissionStatus.limited;
  }

  Future<bool> openSettings() => _service.openSettings();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(recheckAll());
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
