import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:service_extensions/service_extensions.dart';

import 'actions.dart';
import 'common.dart';
import 'finder.dart';
import 'ghost_overlay.dart';
import 'overlays.dart';
import 'router_adapter.dart';
import 'semantics.dart';
import 'telemetry.dart';
import 'version.dart';

/// The internal implementation of the Slipstream agent.
class Agent {
  static final Agent _instance = Agent._();

  /// The singleton instance of the [Agent].
  static Agent get instance => _instance;

  bool _initialized = false;

  Agent._();

  /// Initializes the agent and registers service extensions.
  ///
  /// [router] is an optional routing adapter for `ext.slipstream.navigate`.
  void initialize({RouterAdapter? router}) {
    if (_initialized) return;
    _initialized = true;

    for (final ext in [
      _PingExtension(),
      _GetRouteExtension(router),
      _NavigateExtension(router),
      _PerformActionExtension(),
      _EnableSemanticsExtension(),
      _GetSemanticsExtension(),
      _OverlaysExtension(),
      _LogExtension(),
      _ClearErrorsExtension(),
    ]) {
      registerServiceExtension(ext.description, ext.handleCall);
    }

    initTelemetry();
  }
}

Future<void> _waitForNextFrame() async {
  final completer = Completer<void>();
  WidgetsBinding.instance.scheduleFrameCallback(
    (timeStamp) => completer.complete(),
    scheduleNewFrame: true,
  );
  await completer.future;
}

abstract class AgentExtension {
  ServiceDescription get description;

  Future<Map<String, Object?>> handleCall(ExtensionParameters parameters);
}

// ---------------------------------------------------------------------------
// Extensions

class _PingExtension extends AgentExtension {
  @override
  final ServiceDescription description = ServiceDescription(
    name: 'ext.slipstream.ping',
    description: 'Checks the status of the Slipstream agent.',
    returns: [
      ReturnDescription(
        name: 'version',
        type: 'String',
        description: 'The slipstream_agent version.',
      ),
    ],
  );

  @override
  Future<Map<String, Object?>> handleCall(ExtensionParameters _) async {
    GhostOverlay.install();
    return {'version': packageVersion};
  }
}

class _GetRouteExtension extends AgentExtension {
  _GetRouteExtension(this._router);

  final RouterAdapter? _router;

  @override
  final ServiceDescription description = ServiceDescription(
    name: 'ext.slipstream.get_route',
    description:
        'Returns the current route path from the registered router adapter. '
        'Requires SlipstreamAgent.init(router: ...) to have been called.',
    returns: [
      ReturnDescription(
        name: 'path',
        type: 'String',
        description: 'The current route path, e.g. "/podcast/123".',
      ),
    ],
  );

  @override
  Future<Map<String, Object?>> handleCall(ExtensionParameters _) async {
    GhostOverlay.log('get route', kind: 'read');
    final path = _router?.currentPath();
    if (path == null) {
      return {
        'ok': false,
        'error': 'get_route: no router adapter registered or path unavailable',
      };
    }
    return {'ok': true, 'path': path};
  }
}

class _NavigateExtension extends AgentExtension {
  _NavigateExtension(this._router);

  final RouterAdapter? _router;

  @override
  final ServiceDescription description = ServiceDescription(
    name: 'ext.slipstream.navigate',
    description: 'Navigates the app to a route path via the registered router '
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
    returns: [
      ReturnDescription(
          name: 'ok', type: 'bool', description: 'The status of the call.'),
      ReturnDescription(
          name: 'error',
          type: 'String',
          description: 'A message describing any error.'),
    ],
  );

  @override
  Future<Map<String, Object?>> handleCall(
      ExtensionParameters parameters) async {
    final String path = parameters.asStringRequired('path');

    if (_router == null) {
      return {
        'ok': false,
        'error': 'navigate: no router adapter registered. Call '
            'SlipstreamAgent.init(router: GoRouterAdapter(appRouter)) in '
            'main().',
      };
    }

    final Element? root = WidgetsBinding.instance.rootElement;
    if (root == null) {
      return {'ok': false, 'error': 'navigate: widget tree not yet built'};
    }

    try {
      GhostOverlay.log('navigate', details: path, kind: 'interact');
      _router.go(root, path);
      await pumpAndMostlySettle();
      return {'ok': true};
    } catch (e) {
      return {'ok': false, 'error': 'navigate: $e'};
    }
  }
}

class _PerformActionExtension extends AgentExtension {
  @override
  final ServiceDescription description = ServiceDescription(
    name: 'ext.slipstream.perform_action',
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
        description: 'How to find the widget: "byKey", "byType", "byText", '
            '"byTextContaining", or "bySemanticsLabel".',
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
        description: 'Required for scroll: "up", "down", "left", or "right".',
      ),
      ParameterDescription(
        name: 'pixels',
        type: 'double',
        description: 'Required for scroll: number of logical pixels.',
      ),
      ParameterDescription(
        name: 'scrollFinder',
        type: 'String',
        description: 'Required for scroll_until_visible: finder type for the '
            'Scrollable widget.',
      ),
      ParameterDescription(
        name: 'scrollFinderValue',
        type: 'String',
        description: 'Required for scroll_until_visible: finder value for the '
            'Scrollable widget.',
      ),
    ],
    returns: [
      ReturnDescription(
          name: 'ok', type: 'bool', description: 'The status of the call.'),
      ReturnDescription(
          name: 'error',
          type: 'String',
          description: 'A message describing any error.'),
    ],
  );

  @override
  Future<Map<String, Object?>> handleCall(
      ExtensionParameters parameters) async {
    final String action = parameters.asStringRequired('action');
    final String finder = parameters.asStringRequired('finder');
    final String finderValue = parameters.asStringRequired('finderValue');
    final String? text = parameters.asString('text');
    final String? direction = parameters.asString('direction');
    final double? pixels = parameters.asDouble('pixels');
    final String? scrollFinder = parameters.asString('scrollFinder');
    final String? scrollFinderValue = parameters.asString('scrollFinderValue');

    // For scroll_until_visible the target may not be in the tree yet (lazy
    // list), so we defer the lookup to scrollUntilVisible itself. All other
    // actions require the element to be present up front.
    final element = action == 'scroll_until_visible'
        ? null
        : findElement(finder: finder, value: finderValue);
    if (element == null && action != 'scroll_until_visible') {
      return {
        'ok': false,
        'error': 'interact: no element found for finder="$finder" '
            'value="$finderValue"',
      };
    }

    String? error;
    switch (action) {
      case 'tap':
        GhostOverlay.log('tap',
            details: finderValue,
            kind: 'interact',
            finder: finder,
            finderValue: finderValue,
            viz: 'outline');
        error = await tapElement(element!);
      case 'set_text':
        if (text == null) {
          error = 'interact: "text" is required for the set_text action';
        } else {
          GhostOverlay.log('set text',
              details: '"$text"',
              kind: 'interact',
              finder: finder,
              finderValue: finderValue,
              viz: 'outline');
          error = setTextInElement(element!, text);
        }
      case 'scroll':
        if (direction == null) {
          error = 'interact: "direction" is required for the scroll action';
        } else if (pixels == null) {
          error = 'interact: "pixels" is required for the scroll action';
        } else {
          GhostOverlay.log('scroll',
              details: '$direction ${pixels.round()}px',
              kind: 'interact',
              finder: finder,
              finderValue: finderValue,
              viz: 'outline');
          error = await scrollElement(
            element!,
            direction: direction,
            pixels: pixels,
          );
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
            GhostOverlay.log('scroll to',
                details: finderValue,
                kind: 'interact',
                finder: finder,
                finderValue: finderValue,
                viz: 'outline');
            error = await scrollUntilVisible(
              targetFinder: finder,
              targetFinderValue: finderValue,
              scrollableElement: scrollable,
            );
          }
        }
      default:
        error = 'interact: unknown action "$action"';
    }

    if (error != null) {
      return {'ok': false, 'error': error};
    }

    await pumpAndMostlySettle();

    return {'ok': true};
  }
}

class _EnableSemanticsExtension extends AgentExtension {
  @override
  final ServiceDescription description = ServiceDescription(
    name: 'ext.slipstream.enable_semantics',
    description: 'Enables the Flutter semantics tree and schedules a frame to '
        'ensure it is populated.',
  );

  @override
  Future<Map<String, Object?>> handleCall(ExtensionParameters _) async {
    GhostOverlay.log('enable semantics', kind: 'read');
    RendererBinding.instance.ensureSemantics();
    await _waitForNextFrame();
    return {};
  }
}

class _GetSemanticsExtension extends AgentExtension {
  @override
  final ServiceDescription description = ServiceDescription(
    name: 'ext.slipstream.get_semantics',
    description:
        'Returns a flat list of visible semantics nodes from the running app. '
        'Each node is a JSON object with the same fields as SemanticNode in '
        'flutter_slipstream: id, role, label, value, hint, checked, toggled, '
        'selected, enabled, focused, actions, left, top, right, bottom. '
        'Coordinates are in screen-space logical pixels (more accurate than '
        'the out-of-process evaluate-based implementation). '
        'Call ext.slipstream.enable_semantics first if the tree is empty.',
    returns: [
      ReturnDescription(
          name: 'ok', type: 'bool', description: 'The status of the call.'),
      ReturnDescription(
        name: 'nodes',
        type: 'List',
        description: 'List of semantics node objects (present when ok=true).',
      ),
      ReturnDescription(
        name: 'error',
        type: 'String',
        description: 'Error message (present when ok=false).',
      ),
    ],
  );

  @override
  Future<Map<String, Object?>> handleCall(ExtensionParameters _) async {
    GhostOverlay.log('get semantics', kind: 'read', viz: 'semantics');
    final (nodes, error) = getSemanticsNodes();
    if (error != null) return {'ok': false, 'error': error};
    return {'ok': true, 'nodes': nodes!.map((n) => n.toMap()).toList()};
  }
}

class _OverlaysExtension extends AgentExtension {
  @override
  final ServiceDescription description = ServiceDescription(
    name: 'ext.slipstream.overlays',
    description:
        'Shows or hides all Slipstream-managed overlays (debug banner, and '
        'future Slipstream overlays). Passing enabled=false saves the current '
        'overlay state and hides everything; passing enabled=true restores the '
        'previously saved state. Triggers a frame rebuild after each change.',
    parameters: [
      ParameterDescription(
        name: 'enabled',
        type: 'bool',
        description:
            'false to hide all overlays (saving state); true to restore.',
        required: true,
      ),
    ],
    returns: [
      ReturnDescription(
          name: 'ok', type: 'bool', description: 'The status of the call.'),
      ReturnDescription(
          name: 'error',
          type: 'String',
          description: 'A message describing any error.'),
    ],
  );

  @override
  Future<Map<String, Object?>> handleCall(
      ExtensionParameters parameters) async {
    final enabled = parameters.asBoolRequired('enabled');
    setOverlaysEnabled(enabled);
    await _waitForNextFrame();
    return {'ok': true};
  }
}

class _LogExtension extends AgentExtension {
  @override
  final ServiceDescription description = ServiceDescription(
    name: 'ext.slipstream.log',
    description:
        'Logs an agent command to the ghost overlay command log. Called by the '
        'Slipstream MCP server for operations that do not flow through an '
        'in-process extension (e.g. hot reload, screenshot, evaluate). '
        'In-process extensions log automatically.',
    parameters: [
      ParameterDescription(
        name: 'command',
        type: 'String',
        description:
            'Short label for the command, e.g. "reload", "screenshot".',
        required: true,
      ),
      ParameterDescription(
        name: 'details',
        type: 'String',
        description: 'Optional detail appended after a colon, '
            'e.g. a route path or text value.',
      ),
      ParameterDescription(
        name: 'kind',
        type: 'String',
        description: 'Icon category hint: "read", "interact", "reload", or '
            '"screenshot".',
      ),
      ParameterDescription(
        name: 'finder',
        type: 'String',
        description: 'Finder type for the widget of interest '
            '("byKey", "byType", "byText", "bySemanticsLabel"). '
            'Used with viz="outline" or viz="layout".',
      ),
      ParameterDescription(
        name: 'finderValue',
        type: 'String',
        description: 'Value to match against the chosen finder.',
      ),
      ParameterDescription(
        name: 'viz',
        type: 'String',
        description: 'Extra visualization: "flash" (full-screen tint), '
            '"outline" (widget bounding box), '
            '"layout" (bounding box with layout annotations), or '
            '"semantics" (all semantics node outlines).',
      ),
    ],
    returns: [
      ReturnDescription(name: 'ok', type: 'bool', description: 'Always true.'),
    ],
  );

  @override
  Future<Map<String, Object?>> handleCall(
      ExtensionParameters parameters) async {
    GhostOverlay.log(
      parameters.asStringRequired('command'),
      details: parameters.asString('details'),
      kind: parameters.asString('kind'),
      finder: parameters.asString('finder'),
      finderValue: parameters.asString('finderValue'),
      viz: parameters.asString('viz'),
    );
    return {'ok': true};
  }
}

class _ClearErrorsExtension extends AgentExtension {
  @override
  final ServiceDescription description = ServiceDescription(
    name: 'ext.slipstream.clear_errors',
    description:
        'Clears the persistent flutter.error banner from the ghost overlay. '
        'Call after reading error output (e.g. after get_output) or after a '
        'hot reload to acknowledge the errors.',
    returns: [
      ReturnDescription(name: 'ok', type: 'bool', description: 'Always true.'),
    ],
  );

  @override
  Future<Map<String, Object?>> handleCall(ExtensionParameters _) async {
    GhostOverlay.clearErrors();
    return {'ok': true};
  }
}
