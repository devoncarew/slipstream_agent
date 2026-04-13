# slipstream_agent

## Purpose

`slipstream_agent` is an optional in-process companion package for the
[flutter_slipstream](https://github.com/devoncarew/flutter_slipstream) Claude
Code plugin. It upgrades the Slipstream MCP inspector server from _external
observation_ to _internal cooperation_ by registering typed VM service
extensions (`ext.slipstream.*`) inside the running Flutter app.

The MCP server calls `ext.slipstream.ping` at session start. If the call
succeeds, the server routes tool calls through these typed extensions instead of
fragile `evaluate` strings. If it fails, all tools fall back silently to the
baseline VM service / evaluate approach.

## Repo Layout

```
slipstream_agent/   — the pub package (published to pub.dev)
slipstream_showcase/ — a Flutter app that exercises the extensions manually
```

## Key Files

| File                                           | Role                                                           |
| ---------------------------------------------- | -------------------------------------------------------------- |
| `slipstream_agent/lib/slipstream_agent.dart`   | Public API — `SlipstreamAgent.init()`                          |
| `slipstream_agent/lib/src/agent.dart`          | All extension registration and handlers                        |
| `slipstream_agent/lib/src/actions.dart`        | UI action implementations (tap, set_text, scroll)              |
| `slipstream_agent/lib/src/finder.dart`         | Element-tree finders (byKey, byType, byText, bySemanticsLabel) |
| `slipstream_agent/lib/src/router_adapter.dart` | `RouterAdapter` interface + `GoRouterAdapter`                  |
| `slipstream_agent/docs/service_extensions.md`  | Protocol reference for all `ext.slipstream.*` extensions       |

## Registered Extensions

All extensions are registered in `Agent.initialize()` (`lib/src/agent.dart`)
using `registerServiceExtension()` from `package:service_extensions`.

| Extension                         | Purpose                                                                |
| --------------------------------- | ---------------------------------------------------------------------- |
| `ext.slipstream.ping`             | Session detection; returns package version                             |
| `ext.slipstream.perform_action`   | Tap, set_text, scroll, scroll_until_visible via element-tree finders   |
| `ext.slipstream.navigate`         | Route navigation via the registered `RouterAdapter`                    |
| `ext.slipstream.get_route`        | Current route path from the registered `RouterAdapter`                 |
| `ext.slipstream.enable_semantics` | Calls `RendererBinding.instance.ensureSemantics()` + `scheduleFrame()` |
| `ext.slipstream.get_semantics` | Returns visible semantics nodes with screen-space bounds (improved vs. out-of-process) |

See `slipstream_agent/docs/service_extensions.md` for the full parameter and
return-value spec for each extension.

## Telemetry Events

In addition to request/response extensions, the agent posts events to the VM
service `Extension` stream via `dart:developer.postEvent`. Clients subscribe
with `streamListen('Extension')` and filter by `event.extensionKind`.

| Event | Trigger | Source |
| ----- | ------- | ------ |
| `ext.slipstream.windowResized` | Window/display metrics change | `WidgetsBindingObserver.didChangeMetrics` |

Telemetry is initialized automatically by `Agent.initialize()` via
`initTelemetry()` in `lib/src/telemetry.dart`. New events go in that file;
register the observer hook there and document in `service_extensions.md`.

## Adding a New Extension

1. Add a `ServiceDescription` field and a handler method to `Agent` in
   `lib/src/agent.dart`.
2. Call `registerServiceExtension(description, handler)` inside
   `Agent.initialize()`.
3. Handler signature:
   `Future<Map<String, Object?>> _myExtension(ExtensionParameters params)`
4. Document the new extension in `slipstream_agent/docs/service_extensions.md`
   following the existing format.

## Initialization Pattern (App Side)

```dart
// In main(), guarded by kDebugMode:
if (kDebugMode) {
  SlipstreamAgent.init(
    router: GoRouterAdapter(appRouter), // optional
  );
}
```

`SlipstreamAgent.init()` is a no-op outside `kDebugMode`. All extensions are
automatically tree-shaken from release builds.

## Core Principles

- **Zero-config baseline:** The flutter_slipstream MCP server must remain fully
  functional without this package installed. These extensions unlock _enhanced_
  capabilities, never required ones.
- **Debug-only:** Never call or register anything outside `kDebugMode`. No
  production leakage.
- **Graceful degradation:** If the MCP server gets a "method not found" response
  to `ext.slipstream.ping`, it silently falls back. Don't break baseline mode.
- **Explicit opt-in:** The MCP server must never add this package to
  `pubspec.yaml` without developer consent.

## Development

```sh
# Run the showcase app (exercises extensions interactively):
cd slipstream_showcase && flutter run

# Run package tests:
cd slipstream_agent && flutter test

# Analyze:
cd slipstream_agent && dart analyze
```

## Companion Project

The MCP server that _calls_ these extensions lives in
`/Users/devoncarew/projects/devoncarew/flutter_slipstream` (the
`flutter_slipstream` repo). The design rationale, phasing plan, and full
architectural context are in:

- `flutter_slipstream/DESIGN.md` — overall plugin architecture
- `flutter_slipstream/docs/slipstream_agent.md` — companion package design doc
