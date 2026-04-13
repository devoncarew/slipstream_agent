import 'dart:developer' show postEvent;

import 'package:flutter/widgets.dart';

/// Adapter interface that lets slipstream_agent navigate the app without
/// knowing which routing library is in use.
///
/// Register an adapter via [SlipstreamAgent.init]:
///
/// ```dart
/// SlipstreamAgent.init(router: GoRouterAdapter(appRouter));
/// ```
abstract class RouterAdapter {
  /// Navigates to [path].
  ///
  /// [path] is a route path such as `"/podcast/123"`. The adapter is
  /// responsible for translating this to the routing library's API.
  ///
  /// Should be called on the UI thread. Returns normally on success; throws
  /// on failure.
  void go(BuildContext context, String path);

  /// Returns the current route path (e.g. `"/podcast/123"`), or null if the
  /// path cannot be determined.
  String? currentPath();
}

/// [RouterAdapter] implementation for the `go_router` package.
///
/// Pass the app's [GoRouter] instance directly:
///
/// ```dart
/// // In main():
/// final _router = GoRouter(routes: [...]);
///
/// SlipstreamAgent.init(router: GoRouterAdapter(_router));
/// ```
class GoRouterAdapter extends RouterAdapter {
  /// The [GoRouter] instance. Declared as `dynamic` to avoid a hard
  /// compile-time dependency on the `go_router` package. At runtime, this must
  /// be a `GoRouter` with a `.go(String path)` method and a `.state.uri`
  /// getter, and it must implement [Listenable].
  GoRouterAdapter(this._router) {
    // GoRouter extends ChangeNotifier, so it is a Listenable. We cast via the
    // Flutter-provided interface rather than importing go_router.
    (_router as Listenable).addListener(_onRouteChanged);
  }

  final dynamic _router;

  void _onRouteChanged() {
    final path = currentPath();
    if (path != null) {
      postEvent('ext.slipstream.routeChanged', {'path': path});
    }
  }

  @override
  void go(BuildContext context, String path) {
    // Calls GoRouter.go(path) dynamically — no import of go_router needed.
    // ignore: avoid_dynamic_calls
    _router.go(path);
  }

  @override
  String? currentPath() {
    try {
      // Calls GoRouter.state.uri.toString() dynamically.
      // ignore: avoid_dynamic_calls
      return _router.state.uri.toString();
    } catch (_) {
      return null;
    }
  }
}
