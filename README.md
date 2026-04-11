# slipstream_agent

This repo contains two packages that together support the
[Slipstream Flutter agent tools](https://github.com/devoncarew/flutter-agent-tools)
MCP plugin.

## Packages

### [slipstream_agent](slipstream_agent/)

An optional, opt-in `dev_dependency` that upgrades the connection between the
Slipstream MCP server and your running Flutter app — from external observation
to internal cooperation.

Key features:

- **Advanced UI Finders:** Target widgets by `Key`, `Type`, or `Text` without needing explicit `Semantics` annotations.
- **Scroll Support:** Programmatically scroll off-screen content into view.
- **Unified Routing:** Provides a uniform interface for programmatic navigation across routing libraries.
- **Ghost Overlay:** Visual feedback showing exactly what the agent is currently targeting.

Add it as a dev dependency:

```bash
flutter pub add dev:slipstream_agent
```

Initialize it in `main()`:

```dart
import 'package:slipstream_agent/slipstream_agent.dart';

void main() {
  SlipstreamAgent.init();
  runApp(const MyApp());
}
```

### [slipstream_showcase](slipstream_showcase/)

A sample Flutter app used for integration testing of the Slipstream MCP plugin.
Themed as a "Stellar Catalog" astronomy browser, it exercises a broad set of MCP
tool interactions across three routes: `Discover` (navigation and list taps),
`Widgets` (text input, buttons, switches, evaluate), and `Events` (print, layout
errors, runtime faults).

```sh
cd slipstream_showcase
flutter run -d macos
```
