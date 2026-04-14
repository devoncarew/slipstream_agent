# slipstream_agent

A companion package for the
[Flutter Slipstream](https://github.com/devoncarew/flutter-slipstream) AI agent
tools.

Install this package to give Slipstream deeper access to your running app.
Without it, Slipstream works through external VM service observation — reliable,
but limited. With it, the agent can find and interact with any widget in your
tree, navigate programmatically regardless of which routing library you use, and
receive real-time telemetry as you build your app.

## When used with Flutter Slipstream

- **Find any widget, not just labelled ones.** The baseline tools rely on the
  Flutter semantics tree, which only knows about widgets with explicit
  accessibility labels. With this package, the agent can target widgets by
  `Key`, type, or visible text — no `Semantics` annotations needed.

- **Accurate layout information.** The semantics query extension accumulates
  transform matrices as it walks the widget tree, so reported bounds are true
  screen-space coordinates rather than each node's unreliable local coordinate
  space.

- **Navigate any router.** The baseline `navigate` tool is go_router-specific.
  With a `RouterAdapter`, navigation and route queries work the same way
  regardless of which routing library your app uses.

- **Real-time telemetry.** The agent receives structured events as your app runs
  — window resizes, route changes — without polling.

## Getting started

Add `slipstream_agent` as a dependency (the package uses debug-only APIs and is
fully tree-shaken from release builds):

```yaml
dependencies:
  slipstream_agent: ^1.0.0
```

Or with the CLI:

```bash
flutter pub add slipstream_agent
```

Then initialize in `main()`:

```dart
import 'package:flutter/foundation.dart';
import 'package:slipstream_agent/slipstream_agent.dart';

void main() {
  if (kDebugMode) {
    SlipstreamAgent.init();
  }
  runApp(const MyApp());
}
```

### With go_router

```dart
final GoRouter _router = GoRouter(routes: [...]);

void main() {
  if (kDebugMode) {
    SlipstreamAgent.init(router: GoRouterAdapter(_router));
  }
  runApp(MyApp(router: _router));
}
```

`GoRouterAdapter` has no compile-time dependency on `go_router` — the router
instance is accepted as `dynamic`.

## How it works

When Slipstream connects to your app, it calls `ext.slipstream.ping`. If the
call succeeds, the server routes tool calls through the typed in-process
extensions this package registers. If the package is not installed, all tools
fall back silently to the baseline behavior.

Extensions are registered under the `ext.slipstream.*` namespace:

| Extension                         | Description                                              |
| --------------------------------- | -------------------------------------------------------- |
| `ext.slipstream.ping`             | Session detection; returns the package version           |
| `ext.slipstream.perform_action`   | Tap, set_text, scroll, scroll_until_visible              |
| `ext.slipstream.enable_semantics` | Enables the Flutter semantics tree                       |
| `ext.slipstream.get_semantics`    | Returns visible semantics nodes with screen-space bounds |
| `ext.slipstream.navigate`         | Navigates to a route path via the router adapter         |
| `ext.slipstream.get_route`        | Returns the current route path via the router adapter    |

See [`docs/service_extensions.md`](docs/service_extensions.md) for the full
protocol reference.
