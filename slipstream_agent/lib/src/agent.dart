import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:service_extensions/service_extensions.dart';

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

    registerServiceExtension(
      ServiceDescription(
        name: 'ext.slipstream.ping',
        description: 'Checks the status of the Slipstream agent.',
        returns: 'A status object.',
      ),
      _ping,
    );

    registerServiceExtension(
      ServiceDescription(
        name: 'ext.slipstream.echo',
        description: 'Echoes back a message.',
        parameters: [
          ParameterDescription(
            name: 'message',
            type: 'String',
            description: 'The message to echo.',
            required: true,
          ),
          ParameterDescription(
            name: 'name',
            type: 'String',
            description: 'An optional name to include.',
          ),
        ],
        returns: 'The echoed message.',
      ),
      _echo,
    );
  }

  Future<Map<String, Object?>> _ping(
      ServiceExtensionParameters parameters) async {
    return {
      'status': 'ok',
      'version': '0.1.0',
      'flutterVersion': kIsWeb ? 'web' : 'native',
    };
  }

  Future<String> _echo(ServiceExtensionParameters parameters) async {
    final message = parameters.asStringRequired('message');
    final name = parameters.asString('name');

    return name != null ? 'hello $name; => $message' : '=> $message';
  }
}
