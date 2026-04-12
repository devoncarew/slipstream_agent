# slipstream_agent

This repo contains two packages that together support the
[Slipstream Flutter agent tools](https://github.com/devoncarew/flutter-agent-tools)
MCP plugin.

## Packages

| Package                                     | Description                                                                                                                                                                                                                                                                                                                                              |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [slipstream_agent](slipstream_agent/)       | An optional, opt-in `dev_dependency` that upgrades the connection between the Slipstream MCP server and your running Flutter app — from external observation to internal cooperation.                                                                                                                                                                    |
| [slipstream_showcase](slipstream_showcase/) | A sample Flutter app used for integration testing of the Slipstream MCP plugin. Themed as a "Stellar Catalog" astronomy browser, it exercises a broad set of MCP tool interactions across three routes: `Discover` (navigation and list taps), `Widgets` (text input, buttons, switches, evaluate), and `Events` (print, layout errors, runtime faults). |
