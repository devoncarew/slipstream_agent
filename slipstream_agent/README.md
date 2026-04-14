# slipstream_agent

An in-process companion package for the
[Flutter Slipstream](https://github.com/devoncarew/flutter-slipstream) agent
tools.

`package:slipstream_agent` is an optional, opt-in `dev_dependency` that upgrades
the connection between the Flutter Slipstream MCP server and your running app —
from external observation to internal cooperation.

When the MCP server detects the package (via `ext.slipstream.ping`), it
automatically routes tool calls through typed in-process extensions instead of
fragile `evaluate` strings. If the package is not installed, all tools fall back
silently to the baseline behavior.

## Features

- **Advanced UI finders:** Target widgets by `Key`, type, or text content
  without requiring explicit `Semantics` annotations. Supported finders:
  `byKey`, `byType`, `byText`, `bySemanticsLabel`.
- **Scroll support:** Programmatically scroll by a fixed amount or scroll until
  a target widget is visible.
- **Semantics tree:** Enable the Flutter semantics tree and query visible nodes
  with accurate screen-space bounds.
- **Unified routing:** Navigate and query the current route via a
  router-agnostic adapter. Includes `GoRouterAdapter` for `go_router` apps.
- **Telemetry events:** Broadcasts structured VM service events for window
  resizes (`ext.slipstream.windowResized`) and route changes
  (`ext.slipstream.routeChanged`).

## Getting started

Add `slipstream_agent` as a dependency:

```yaml
dependencies:
  slipstream_agent: ^0.1.0
```

Or with the CLI:

```bash
flutter pub add slipstream_agent
```

## Usage

Initialize the agent in your `main()` function, guarded by `kDebugMode` so it is
fully tree-shaken from release builds:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:slipstream_agent/slipstream_agent.dart';

void main() {
  if (kDebugMode) {
    SlipstreamAgent.init();
  }
  runApp(const MyApp());
}
```

### With go_router

Pass a `GoRouterAdapter` to enable the `navigate` and `get_route` extensions and
receive `ext.slipstream.routeChanged` telemetry events:

```dart
final _router = GoRouter(routes: [...]);

void main() {
  if (kDebugMode) {
    SlipstreamAgent.init(router: GoRouterAdapter(_router));
  }
  runApp(MyApp(router: _router));
}
```

`GoRouterAdapter` does not add a compile-time dependency on `go_router` — it
accepts the router instance as `dynamic` and accesses it via the `Listenable`
interface and dynamic method calls.

## Service extensions

All extensions are registered under the `ext.slipstream.*` namespace. See
[`docs/service_extensions.md`](docs/service_extensions.md) for the full protocol
reference.

| Extension                         | Description                                              |
| --------------------------------- | -------------------------------------------------------- |
| `ext.slipstream.ping`             | Session detection; returns the package version           |
| `ext.slipstream.perform_action`   | Tap, set_text, scroll, scroll_until_visible              |
| `ext.slipstream.enable_semantics` | Enables the Flutter semantics tree                       |
| `ext.slipstream.get_semantics`    | Returns visible semantics nodes with screen-space bounds |
| `ext.slipstream.navigate`         | Navigates to a route path via the router adapter         |
| `ext.slipstream.get_route`        | Returns the current route path via the router adapter    |
