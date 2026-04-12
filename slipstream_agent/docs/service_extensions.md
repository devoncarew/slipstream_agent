# slipstream_agent Service Extension Protocol

This document defines the VM service extensions registered by
`package:slipstream_agent`. The Slipstream MCP server (`inspector` server)
calls these extensions when the companion package is detected.

Detection: the MCP server calls `ext.slipstream.ping` on session start. If the
call succeeds, enhanced mode is active. If it fails (method not found), the
server falls back to baseline behaviour.

All extensions are registered by `SlipstreamAgent.init()`, which must be called
in `kDebugMode` only. They are automatically stripped from release builds.

---

## `ext.slipstream.ping`

Heartbeat / discovery. Called once per session to detect the companion package.

**Parameters:** none

**Returns:**

```json
{
  "status": "ok",
  "version": "0.1.0",
  "flutterVersion": "native" | "web"
}
```

`version` is the `slipstream_agent` package version. The MCP server stores this
and exposes it as `session.companionVersion`.

---

## `ext.slipstream.interact`

Performs a UI action on a widget located by a finder. Replaces the
semantics-tree evaluate path for tap and set_text when the companion is
installed.

**Parameters:**

| Name | Type | Required | Description |
|---|---|---|---|
| `action` | String | yes | `"tap"` or `"set_text"` |
| `finder` | String | yes | `"byKey"`, `"byType"`, `"byText"`, or `"bySemanticsLabel"` |
| `finderValue` | String | yes | Value to match against the chosen finder |
| `text` | String | for set_text | Text to set; replaces the field's current content |

**Finder semantics:**

| Finder | Matches when |
|---|---|
| `byKey` | Widget has a `ValueKey<String>` equal to `finderValue`, or a `ValueKey<int>` whose `.toString()` equals `finderValue` |
| `byType` | `widget.runtimeType.toString() == finderValue` (e.g. `"ElevatedButton"`) |
| `byText` | Widget is a `Text` and `Text.data == finderValue` |
| `bySemanticsLabel` | Widget is a `Semantics` and `properties.label == finderValue` |

The tree is walked depth-first from the root; the first match is used.

**Returns:**

Success:
```json
{ "ok": true }
```

Failure:
```json
{ "ok": false, "error": "interact: no element found for finder=\"byKey\" value=\"login_button\"" }
```

**Action details:**

- **tap** — resolves the element's `RenderBox`, synthesizes a `PointerDownEvent`
  + `PointerUpEvent` at the center of the element via
  `GestureBinding.handlePointerEvent`. Triggers `GestureDetector.onTap`,
  `InkWell.onTap`, and any other gesture recognizers on the widget.

- **set_text** — walks the element's subtree to find an `EditableTextState` and
  sets `state.widget.controller.text = text`. Replaces the field's current
  content entirely. The field must be part of the widget tree (i.e. it must
  have been built at least once). Tap the field first if focus is required.

- **scroll** — finds a `Scrollable` in the element's subtree and calls
  `position.animateTo(pixels + delta)`. Required params: `direction` (`"up"`,
  `"down"`, `"left"`, `"right"`) and `pixels` (logical pixels as a string).
  Clamped to the scroll extent bounds.

- **scroll_until_visible** — scrolls the `Scrollable` identified by
  `scrollFinder`/`scrollFinderValue` until the target element is in the
  viewport. Uses `RenderAbstractViewport.getOffsetToReveal` to compute the
  target offset. Retries up to 20 steps of 200 px if the target is not yet
  laid out. Required params: `scrollFinder`, `scrollFinderValue`.

---

## `ext.slipstream.navigate`

Navigates the app to a route path using the registered router adapter.

> **Status:** implemented.

**Parameters:**

| Name | Type | Required | Description |
|---|---|---|---|
| `path` | String | yes | Route path, e.g. `"/podcast/123"` |

**Returns:**

```json
{ "ok": true }
```

or

```json
{ "ok": false, "error": "navigate: no router adapter registered" }
```

The router adapter is registered via `SlipstreamAgent.init(router: ...)`. See
the design doc (`slipstream_agent_design.md`) for the `RouterAdapter` interface
and available adapters.
