## 1.2.1

- Fix `scroll_until_visible` for lazy/virtual lists: the target finder is now
  re-evaluated after each scroll step so that `ListView.builder` items are
  discovered as they enter the render tree. Previously the element was looked up
  once before scrolling began, causing the action to fail immediately for any
  item not yet built.
- For the 'scroll: xx px' toast, display the scroll rounded to the nearest int.

## 1.2.0

- `ext.slipstream.perform_action` and `ext.slipstream.navigate` now wait for the
  widget tree to settle before returning, giving animations and navigation
  transitions time to complete before the next tool call.
- Add a persistent error banner: `FlutterError.onError` is intercepted and
  surfaces errors as a red chip near the top of the screen showing a running
  count and a brief summary, e.g. `flutter.error: Null check operator…`. The
  banner is visible in agent screenshots and clears automatically on hot reload
  or via the new `ext.slipstream.clear_errors` extension.
- Add `ext.slipstream.clear_errors` extension: dismisses the error banner (call
  after `get_output` or whenever the agent has acknowledged the errors).
- Add `byTextContaining` finder: matches a `Text` widget whose content contains
  the given value as a substring. Useful when displayed text is truncated (e.g.
  `"Lorem ipsum..."` vs the full string).
- Remove the `ext.slipstream.windowResized` telemetry event. VM service events
  are not pushed into agent context, so agents would need to poll for them —
  making the event low value in practice.

## 1.1.1

- Fix ghost overlay not appearing in apps that use `MaterialApp.router` (e.g.
  GoRouter with `ShellRoute`). In current Flutter, `OverlayEntry.mounted` only
  becomes `true` after the widget builds on the next frame, not immediately
  after `overlay.insert()`. The fix tracks the target `OverlayState` and skips
  re-insertion when the entry is pending its first build on the same overlay.
- Addressed an intermittent error after a hot restart; "Multiple widgets used
  the same GlobalKey".
- Fix `bySemanticsLabel` finder missing widgets whose semantics label comes from
  an implicit source (e.g. `ElevatedButton` merging its child text, `TextField`
  mapping `InputDecoration.labelText`, `Semantics.attributedLabel`). The finder
  now falls back to the render-level semantics node — the same data source as
  `ext.slipstream.get_semantics` — so the label an agent sees in `get_semantics`
  output can always be used to target that widget.

## 1.1.0

- Add `ext.slipstream.log` extension and ghost overlay command log. A
  translucent chip appears at the bottom of the app showing the most recent
  agent action (e.g. "tap: login_button", "navigate: /home"), then slides out
  after 3 seconds. In-process extensions log automatically; the MCP server calls
  `ext.slipstream.log` for out-of-process operations (reload, screenshot,
  evaluate, etc.).
- Ghost overlay now installs on the first `ext.slipstream.ping` (or any log
  call), permanently replacing the Flutter debug banner with a "slipstream"
  banner in the top-right corner. `ext.slipstream.overlays` now only toggles the
  ghost overlay visibility (banner + chips) and no longer saves/restores
  `WidgetsApp.debugAllowBannerOverride`.
- `ext.slipstream.log` accepts `kind`, `finder`, `finderValue`, and `viz`
  parameters for richer visualizations. `kind` controls the icon shown in the
  chip (`"read"`, `"interact"`, `"reload"`, `"screenshot"`). `viz` triggers an
  extra visual effect: `"flash"` (brief full-screen tint), `"outline"` (animated
  bounding-box highlight on the target widget), `"semantics"` (bounding-box
  outlines on all visible semantics nodes), or `"layout"` (falls back to
  `"outline"` for now).
- Fix `ext.slipstream.get_semantics` returning incorrect screen-space
  coordinates. The previous implementation accumulated `SemanticsNode.transform`
  values, which are in physical pixels (scaled by `devicePixelRatio`). The new
  implementation walks the render tree using `RenderBox.localToGlobal`, which
  stays in logical pixels and matches the overlay coordinate system.
  `visitChildrenForSemantics` is used instead of `visitChildren` so that render
  objects excluded from semantics (e.g. inactive `IndexedStack` tabs) are not
  collected.

## 1.0.0

- Add `ext.slipstream.overlays` extension. Calling with `enabled=false` saves
  the current overlay state and hides all managed overlays (currently the
  Flutter debug banner via `WidgetsApp.debugAllowBannerOverride`); calling with
  `enabled=true` restores the previously saved state. Designed for the
  screenshot use case: hide → capture → restore.

## 0.1.2

- Fix `GoRouterAdapter` listener registration: cast to `Listenable` (from
  `flutter/foundation.dart`) rather than a concrete type, restoring the
  zero-`go_router`-dependency design.
- Fix `get_semantics` returning an empty node list: revert semantics owner
  lookup to `pipelineOwner.semanticsOwner` (`rootPipelineOwner` was returning
  null).
- Debounce `ext.slipstream.windowResized` events by 100 ms to avoid flooding
  clients during continuous window resize.
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
