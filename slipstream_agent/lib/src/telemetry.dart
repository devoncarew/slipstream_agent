import 'package:flutter/widgets.dart';

import 'ghost_overlay.dart';

/// Registers framework hooks that surface Flutter errors in the ghost overlay.
///
/// Must be called exactly once — wraps [FlutterError.onError] and is not
/// idempotent. The call site ([Agent.initialize]) guards against re-entry.
///
/// New telemetry hooks go here; document in `docs/service_extensions.md`.
void initTelemetry() {
  final upstream = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    upstream?.call(details);
    GhostOverlay.showError(_extractErrorSummary(details));
  };
}

String _extractErrorSummary(FlutterErrorDetails details) {
  final msg = details.exceptionAsString();
  final first = msg.split('\n').firstWhere(
    (l) => l.trim().isNotEmpty,
    orElse: () => msg,
  );
  final trimmed = first.trim();
  return trimmed.length > 40 ? '${trimmed.substring(0, 38)}…' : trimmed;
}
