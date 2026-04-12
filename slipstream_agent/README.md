# slipstream_agent

An in-process companion package for
[Flutter Slipstream](https://github.com/devoncarew/flutter-slipstream).

`slipstream_agent` is an optional, opt-in `dev_dependency` that upgrades the
connection between the Flutter Slipstream MCP server and your running app from
external observation to internal cooperation.

## Features

- **Advanced UI Finders:** Target widgets by `Key`, `Type`, or `Text` without
  needing explicit `Semantics` annotations.
- **Scroll Support:** Programmatically scroll off-screen content into view.
- **Unified Routing:** Provides a uniform interface for programmatic navigation
  across different routing libraries.
- **Ghost Overlay:** Gives visual feedback in the app showing exactly what the
  agent is currently targeting.

## Getting started

Add `slipstream_agent` as a development dependency:

```bash
flutter pub add dev:slipstream_agent
```

## Usage

Initialize the agent in your `main()` function. The initialization is a no-op
when the app is not in debug mode (`kDebugMode`).

```dart
import 'package:flutter/material.dart';
import 'package:slipstream_agent/slipstream_agent.dart';

void main() {
  // Initialize the Slipstream agent.
  SlipstreamAgent.init();

  runApp(const MyApp());
}
```

The Slipstream MCP server will automatically detect the presence of the agent
and use it to provide enhanced capabilities and reliability.
