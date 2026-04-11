import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:slipstream_agent/src/extension_support.dart';

/// The internal implementation of the Slipstream agent.
class Agent {
  static final Agent _instance = Agent._();

  /// The singleton instance of the [Agent].
  static Agent get instance => _instance;

  Agent._();

  bool _initialized = false;

  /// Initializes the agent and registers service extensions.
  void initialize() {
    if (_initialized) return;
    _initialized = true;

    registerServiceExtension('ext.slipstream.ping', _ping);
    registerServiceExtension('ext.slipstream.echo', _echo);
  }

  Future<Map<String, Object?>> _ping(ExtensionParameters parameters) async {
    return {
      'status': 'ok',
      'version': '0.1.0',
      'flutterVersion': kIsWeb ? 'web' : 'native',
    };
  }

  Future<String> _echo(ExtensionParameters parameters) async {
    final message = parameters.asStringRequired('message');
    final name = parameters.asString('name');

    return name != null ? 'hello $name; => $message' : '=> $message';
  }
}
