import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:service_extensions/service_extensions.dart';

import 'actions.dart';
import 'finder.dart';
import 'router_adapter.dart';

/// The internal implementation of the Slipstream agent.
class Agent {
  static final Agent _instance = Agent._();

  /// The singleton instance of the [Agent].
  static Agent get instance => _instance;

  Agent._();

  bool _initialized = false;
  RouterAdapter? _router;

  /// Initializes the agent and registers service extensions.
  ///
  /// [router] is an optional routing adapter for `ext.slipstream.navigate`.
  void initialize({RouterAdapter? router}) {
    if (_initialized) return;
    _initialized = true;
    _router = router;

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
        name: 'ext.slipstream.interact',
        description:
            'Performs a UI action (tap, set_text) on a widget located by a '
            'finder (byKey, byType, byText, bySemanticsLabel).',
        parameters: [
          ParameterDescription(
            name: 'action',
            type: 'String',
            description: 'The action to perform: "tap" or "set_text".',
            required: true,
          ),
          ParameterDescription(
            name: 'finder',
            type: 'String',
            description:
                'How to find the widget: "byKey", "byType", "byText", or '
                '"bySemanticsLabel".',
            required: true,
          ),
          ParameterDescription(
            name: 'finderValue',
            type: 'String',
            description: 'The value to match against the chosen finder.',
            required: true,
          ),
          ParameterDescription(
            name: 'text',
            type: 'String',
            description: 'Required for the set_text action. The text to set.',
          ),
          ParameterDescription(
            name: 'direction',
            type: 'String',
            description:
                'Required for scroll: "up", "down", "left", or "right".',
          ),
          ParameterDescription(
            name: 'pixels',
            type: 'String',
            description: 'Required for scroll: number of logical pixels.',
          ),
          ParameterDescription(
            name: 'scrollFinder',
            type: 'String',
            description:
                'Required for scroll_until_visible: finder type for the '
                'Scrollable widget.',
          ),
          ParameterDescription(
            name: 'scrollFinderValue',
            type: 'String',
            description:
                'Required for scroll_until_visible: finder value for the '
                'Scrollable widget.',
          ),
        ],
        returns:
            'An object with an "ok" boolean. On failure, includes an "error" '
            'string.',
      ),
      _interact,
    );

    registerServiceExtension(
      ServiceDescription(
        name: 'ext.slipstream.navigate',
        description:
            'Navigates the app to a route path via the registered router '
            'adapter. Requires SlipstreamAgent.init(router: ...) to have been '
            'called.',
        parameters: [
          ParameterDescription(
            name: 'path',
            type: 'String',
            description: 'Route path to navigate to, e.g. "/podcast/123".',
            required: true,
          ),
        ],
        returns:
            'An object with an "ok" boolean. On failure, includes an "error" '
            'string.',
      ),
      _navigate,
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

  Future<Map<String, Object?>> _interact(
    ServiceExtensionParameters parameters,
  ) async {
    final String action = parameters.asStringRequired('action');
    final String finder = parameters.asStringRequired('finder');
    final String finderValue = parameters.asStringRequired('finderValue');
    final String? text = parameters.asString('text');
    final String? direction = parameters.asString('direction');
    final String? pixelsStr = parameters.asString('pixels');
    final String? scrollFinder = parameters.asString('scrollFinder');
    final String? scrollFinderValue = parameters.asString('scrollFinderValue');

    final element = findElement(finder: finder, value: finderValue);
    if (element == null) {
      return {
        'ok': false,
        'error': 'interact: no element found for finder="$finder" '
            'value="$finderValue"',
      };
    }

    String? error;
    switch (action) {
      case 'tap':
        error = await tapElement(element);
      case 'set_text':
        if (text == null) {
          error = 'interact: "text" is required for the set_text action';
        } else {
          error = setTextInElement(element, text);
        }
      case 'scroll':
        if (direction == null) {
          error = 'interact: "direction" is required for the scroll action';
        } else if (pixelsStr == null) {
          error = 'interact: "pixels" is required for the scroll action';
        } else {
          final double? pixels = double.tryParse(pixelsStr);
          if (pixels == null) {
            error = 'interact: "pixels" must be a number, got "$pixelsStr"';
          } else {
            error = await scrollElement(
              element,
              direction: direction,
              pixels: pixels,
            );
          }
        }
      case 'scroll_until_visible':
        if (scrollFinder == null || scrollFinderValue == null) {
          error =
              'interact: "scrollFinder" and "scrollFinderValue" are required '
              'for scroll_until_visible';
        } else {
          final scrollable = findElement(
            finder: scrollFinder,
            value: scrollFinderValue,
          );
          if (scrollable == null) {
            error =
                'interact: no scrollable found for scrollFinder="$scrollFinder"'
                ' value="$scrollFinderValue"';
          } else {
            error = await scrollUntilVisible(
              targetElement: element,
              scrollableElement: scrollable,
            );
          }
        }
      default:
        error = 'interact: unknown action "$action"';
    }

    if (error != null) return {'ok': false, 'error': error};
    return {'ok': true};
  }

  Future<Map<String, Object?>> _navigate(
    ServiceExtensionParameters parameters,
  ) async {
    final String path = parameters.asStringRequired('path');

    if (_router == null) {
      return {
        'ok': false,
        'error': 'navigate: no router adapter registered. Call '
            'SlipstreamAgent.init(router: GoRouterAdapter(appRouter)) in '
            'main().',
      };
    }

    // Obtain a BuildContext from the root element.
    final Element? root = WidgetsBinding.instance.rootElement;
    if (root == null) {
      return {'ok': false, 'error': 'navigate: widget tree not yet built'};
    }

    try {
      _router!.go(root, path);
      return {'ok': true};
    } catch (e) {
      return {'ok': false, 'error': 'navigate: $e'};
    }
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
