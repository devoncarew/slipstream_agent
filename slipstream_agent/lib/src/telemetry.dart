import 'dart:async';
import 'dart:developer' show postEvent;

import 'package:flutter/widgets.dart';

/// Registers framework observers that broadcast structured JSON events to VM
/// service clients via [postEvent].
///
/// Call once from [Agent.initialize]. Safe to call multiple times — the
/// observer is only added once.
void initTelemetry() {
  WidgetsBinding.instance.addObserver(_observer);
}

final _SlipstreamObserver _observer = _SlipstreamObserver();

class _SlipstreamObserver extends WidgetsBindingObserver {
  Timer? _previousEvent;

  /// Fires whenever the window metrics change (resize, rotation, DPR change).
  ///
  /// Posts `ext.slipstream.windowResized` with the logical and physical
  /// dimensions of the implicit view.
  @override
  void didChangeMetrics() {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) {
      return;
    }

    _previousEvent?.cancel();

    final physicalSize = view.physicalSize;
    final dpr = view.devicePixelRatio;

    final data = {
      'viewId': view.viewId,
      'physicalWidth': physicalSize.width,
      'physicalHeight': physicalSize.height,
      'devicePixelRatio': dpr,
      'logicalWidth': physicalSize.width / dpr,
      'logicalHeight': physicalSize.height / dpr,
    };

    // De-bounce the event - when resizing a window we generate a large number
    // of notifications.
    _previousEvent = Timer(const Duration(milliseconds: 100), () {
      postEvent('ext.slipstream.windowResized', data);
    });
  }
}
