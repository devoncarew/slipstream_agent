import 'package:flutter/foundation.dart';

import 'src/agent.dart';
import 'src/router_adapter.dart';

export 'src/router_adapter.dart' show RouterAdapter, GoRouterAdapter;

/// The entry point for the Slipstream companion agent.
class SlipstreamAgent {
  /// Initialize the Slipstream agent.
  ///
  /// Registers VM service extensions that allow the Slipstream MCP server to
  /// interact more deeply with the running app.
  ///
  /// [router] is an optional routing adapter. When provided, the MCP server
  /// can call `navigate` to push routes without knowing which routing library
  /// the app uses. Example:
  ///
  /// ```dart
  /// SlipstreamAgent.init(router: GoRouterAdapter(appRouter));
  /// ```
  ///
  /// This is a no-op if [kDebugMode] is false.
  static void init({RouterAdapter? router}) {
    if (!kDebugMode) return;
    Agent.instance.initialize(router: router);
  }
}
