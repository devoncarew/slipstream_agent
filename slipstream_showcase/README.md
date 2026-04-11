# slipstream_showcase

A sample Flutter app used for integration testing of the
[flutter-slipstream](https://github.com/devoncarew/flutter-agent-tools)
MCP plugin. The app is themed as a "Stellar Catalog" — a lightweight
astronomy browser — to make it feel like a real application rather than
a bare widget demo.

## Running the app

```sh
cd slipstream_showcase
flutter run -d macos
```

## Route inventory

All routes are go_router paths and can be targeted with the `navigate` tool.

| Path | Screen | Notes |
|---|---|---|
| `/discover` | `DiscoverPage` | Scrollable list of stellar objects |
| `/discover/{object_id}` | `DiscoverDetailPage` | Detail view; renders over the shell (no bottom nav). Example: `/discover/betelgeuse` |
| `/widgets` | `WidgetsPage` | Interactive widget showcase |
| `/events` | `EventsPage` | Debug-output and fault-simulation triggers |

Object IDs are the object name lowercased with spaces replaced by underscores:
`betelgeuse`, `sirius`, `andromeda`, `orion_nebula`, `proxima_centauri`,
`pleiades`, `pillars_of_creation`, `sagittarius_a*`, `eta_carinae`.

## What each page exercises

### Discover (`/discover`)

- `get_semantics` + `tap` — tapping a list tile navigates to the detail page
- `navigate` — jump directly to any object, e.g. `navigate('/discover/sirius')`
- `get_route` — after navigating to a detail page the route stack contains both
  the shell route and the full-screen detail route

### Widgets (`/widgets`)

- `set_text` — two text fields: **Observer Name** (`key: input_observer_name`)
  and **Target Object** (`key: input_target_object`)
- `tap` — **Launch Mission** button, **Stand Down** button, **Bookmark** icon
  button, switch, checkbox, radio tiles
- `get_semantics` — all interactive widgets have explicit keys and/or labels
- `evaluate` — two top-level globals in `main.dart` are updated by interactions:
  - `evaluate('tapCount.toString()')` — incremented each time **Launch Mission**
    is tapped
  - `evaluate('lastInput')` — updated on every keystroke in **Observer Name**
- **State Inspector** section at the bottom of the page mirrors all widget state
  visually, so a screenshot can confirm interactions without `evaluate`

### Events (`/events`)

- `tap` → "Call print" — emits a timestamped line via `dart:core` `print`
- `tap` → "Print to stdout" — emits via `dart:io` `stdout` (macOS/Linux only)
- `tap` → "RenderFlex overflow" — pushes a page with a real overflow error;
  use `inspect_layout` to examine the constrained `Column`
- `tap` → "Unbounded viewport height" — button on the sub-page calls
  `FlutterError.reportError` with a simulated unbounded-height error (the real
  layout would make the page non-interactive, so this is synthesized)
- `tap` → "Failed assertion" / "Null check on null value" — trigger runtime
  errors forwarded as MCP log warnings

### Device info drawer

Open with `tap(label: 'Open navigation menu')` (the hamburger button). Displays
platform name, screen size, device pixel ratio, and safe-area insets — useful
for confirming the environment the agent is running in.
