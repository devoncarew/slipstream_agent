import 'package:flutter/foundation.dart';
import 'src/agent.dart';

/// The entry point for the Slipstream companion agent.
class SlipstreamAgent {
  /// Initialize the Slipstream agent.
  ///
  /// This registers VM service extensions that allow the Slipstream MCP server
  /// to interact more deeply with the running app.
  ///
  /// This is a no-op if [kDebugMode] is false.
  static void init() {
    if (!kDebugMode) return;
    Agent.instance.initialize();
  }
}
