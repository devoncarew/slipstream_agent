## 0.1.2

- Fix `GoRouterAdapter` listener registration: cast to `Listenable` (from
  `flutter/foundation.dart`) rather than a concrete type, restoring the
  zero-`go_router`-dependency design.
- Fix `get_semantics` returning an empty node list: revert semantics owner
  lookup to `pipelineOwner.semanticsOwner` (`rootPipelineOwner` was returning
  null).
- Debounce `ext.slipstream.windowResized` events by 100 ms to avoid
  flooding clients during continuous window resize.
- Switch `scrollElement` from `animateTo` to `jumpTo` — animation served no
  purpose for an AI agent caller.

## 0.1.1

- Update `GoRouterAdapter` to reference the router via the [RouterConfig] parent
  type for additional type safety.

## 0.1.0

Initial release.

- `SlipstreamAgent.init()` registers VM service extensions that the Flutter
  Slipstream MCP server uses for enhanced app interaction. All extensions are
  no-ops outside `kDebugMode` and are tree-shaken from release builds.
- Service extensions registered:
  - `ext.slipstream.ping` — session detection and version reporting
  - `ext.slipstream.perform_action` — tap, set_text, scroll, and
    scroll_until_visible via element-tree finders (`byKey`, `byType`, `byText`,
    `bySemanticsLabel`)
  - `ext.slipstream.enable_semantics` — enables the Flutter semantics tree
  - `ext.slipstream.get_semantics` — returns visible semantics nodes as
    structured JSON with screen-space bounds (more accurate than the
    out-of-process evaluate-based implementation)
  - `ext.slipstream.navigate` — navigates to a route path via the registered
    `RouterAdapter`
  - `ext.slipstream.get_route` — returns the current route path via the
    registered `RouterAdapter`
- Telemetry events posted to the VM service `Extension` stream:
  - `ext.slipstream.windowResized` — fired on window/display metric changes
  - `ext.slipstream.routeChanged` — fired on route changes (requires a
    `RouterAdapter`)
- `GoRouterAdapter` provides `go_router` support (but without a transitive
  dependency on `package:go_router`).
