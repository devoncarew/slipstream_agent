# slipstream_agent Service Extension Protocol

This document defines the VM service extensions registered by
`package:slipstream_agent`. The Slipstream MCP server (`inspector` server) calls
these extensions when the companion package is detected.

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
  "version": "0.1.0"
}
```

`version` is the `slipstream_agent` package version. The MCP server stores this
and exposes it as `session.companionVersion`.

---

## `ext.slipstream.perform_action`

Performs a UI action on a widget located by a finder. Replaces the
semantics-tree evaluate path for tap and set_text when the companion is
installed.

**Parameters:**

| Name          | Type   | Required     | Description                                                |
| ------------- | ------ | ------------ | ---------------------------------------------------------- |
| `action`      | String | yes          | `"tap"` or `"set_text"`                                    |
| `finder`      | String | yes          | `"byKey"`, `"byType"`, `"byText"`, or `"bySemanticsLabel"` |
| `finderValue` | String | yes          | Value to match against the chosen finder                   |
| `text`        | String | for set_text | Text to set; replaces the field's current content          |

**Finder semantics:**

| Finder             | Matches when                                                                                                          |
| ------------------ | --------------------------------------------------------------------------------------------------------------------- |
| `byKey`            | Widget has a `ValueKey<String>` equal to `finderValue`, or a `ValueKey<int>` whose `.toString()` equals `finderValue` |
| `byType`           | `widget.runtimeType.toString() == finderValue` (e.g. `"ElevatedButton"`)                                              |
| `byText`           | Widget is a `Text` and `Text.data == finderValue`                                                                     |
| `bySemanticsLabel` | Widget is a `Semantics` and `properties.label == finderValue`                                                         |

The tree is walked depth-first from the root; the first match is used.

**Returns:**

Success:

```json
{ "ok": true }
```

Failure:

```json
{
  "ok": false,
  "error": "interact: no element found for finder=\"byKey\" value=\"login_button\""
}
```

**Action details:**

- **tap** — resolves the element's `RenderBox`, synthesizes a `PointerDownEvent`
  - `PointerUpEvent` at the center of the element via
    `GestureBinding.handlePointerEvent`. Triggers `GestureDetector.onTap`,
    `InkWell.onTap`, and any other gesture recognizers on the widget.

- **set_text** — walks the element's subtree to find an `EditableTextState` and
  sets `state.widget.controller.text = text`. Replaces the field's current
  content entirely. The field must be part of the widget tree (i.e. it must have
  been built at least once). Tap the field first if focus is required.

- **scroll** — finds a `Scrollable` in the element's subtree and calls
  `position.animateTo(pixels + delta)`. Required params: `direction` (`"up"`,
  `"down"`, `"left"`, `"right"`) and `pixels` (logical pixels as a double).
  Clamped to the scroll extent bounds.

- **scroll_until_visible** — scrolls the `Scrollable` identified by
  `scrollFinder`/`scrollFinderValue` until the target element is in the
  viewport. Uses `RenderAbstractViewport.getOffsetToReveal` to compute the
  target offset. Retries up to 20 steps of 200 px if the target is not yet laid
  out. Required params: `scrollFinder`, `scrollFinderValue`.

---

## `ext.slipstream.navigate`

Navigates the app to a route path using the registered router adapter.

**Parameters:**

| Name   | Type   | Required | Description                       |
| ------ | ------ | -------- | --------------------------------- |
| `path` | String | yes      | Route path, e.g. `"/podcast/123"` |

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

---

## `ext.slipstream.enable_semantics`

Enables the Flutter semantics tree and schedules a frame to ensure it is
populated. Call this before any operation that relies on semantics labels (e.g.
`bySemanticsLabel` finders or accessibility assertions).

**Parameters:** none

**Returns:** none

---

## `ext.slipstream.get_semantics`

Returns a flat list of visible semantics nodes from the running app. This is an
in-process alternative to the out-of-process implementation in the Slipstream
MCP server. It is more reliable and includes screen-space bounds.

Call `ext.slipstream.enable_semantics` first if the tree has not been enabled.

**Parameters:** none

**Returns:**

Success:

```json
{
  "ok": true,
  "nodes": [
    {
      "id": 7,
      "role": "button",
      "label": "Betelgeuse Red supergiant · 700 solar radii",
      "value": "",
      "hint": "",
      "checked": null,
      "toggled": null,
      "selected": null,
      "enabled": null,
      "focused": false,
      "actions": 4194305,
      "left": 16.0,
      "top": 200.0,
      "right": 377.0,
      "bottom": 272.0
    }
  ]
}
```

Failure (semantics not enabled or tree empty):

```json
{ "ok": false, "error": "semantics not enabled" }
```

**Node fields:**

<!-- prettier-ignore-start -->
| Field | Type | Description |
| ----- | ---- | ----------- |
| `id` | int | Framework-internal node ID; stable until next hot reload/restart |
| `role` | String | `"button"`, `"textfield"`, `"slider"`, `"link"`, `"image"`, `"header"`, `"checkbox"`, `"toggle"`, `"radio"`, or `""` |
| `label` | String | Primary accessibility label |
| `value` | String | Current value (e.g. slider position, text field content) |
| `hint` | String | Short description of what happens on action |
| `checked` | bool? | Checkbox checked state; `null` if not a checkbox |
| `toggled` | bool? | Toggle/switch on state; `null` if not a toggle |
| `selected` | bool? | Selected state (tabs, list items); `null` if not applicable |
| `enabled` | bool? | Enabled/disabled; `null` if not applicable |
| `focused` | bool | Whether this node currently has input focus |
| `actions` | int | `SemanticsAction` bitmask (tap=1, longPress=2, scrollLeft=4, scrollRight=8, scrollUp=16, scrollDown=32, increase=64, decrease=128, setText=1<<21, focus=1<<22) |
| `left` | double | Screen-space left edge in logical pixels |
| `top` | double | Screen-space top edge in logical pixels |
| `right` | double | Screen-space right edge in logical pixels |
| `bottom` | double | Screen-space bottom edge in logical pixels |
<!-- prettier-ignore-end -->

Trivial nodes (no role, no actions, no label/value/hint, no relevant state) are
elided from the list.

**Improvement over the out-of-process version:** The evaluate-based
implementation cannot accumulate `SemanticsNode.transform` matrices across the
tree, so it reports each node's bounding box in its own local coordinate space —
unreliable for any node that isn't at the root level. This extension walks the
live tree in-process, accumulating transforms, so `left`/`top`/`right`/`bottom`
are true screen-space coordinates.

---

## `ext.slipstream.overlays`

Shows or hides all Slipstream-managed overlays. Designed for use cases like
screenshots where overlays should be temporarily hidden.

Calling with `enabled=false` saves the current overlay state internally and
hides everything. Calling with `enabled=true` restores the previously saved
state. A frame rebuild is triggered after each change.

**Currently managed overlays:**

| Overlay              | Mechanism                             |
| -------------------- | ------------------------------------- |
| Flutter debug banner | `WidgetsApp.debugAllowBannerOverride` |

**Parameters:**

| Name      | Type | Required | Description                                           |
| --------- | ---- | -------- | ----------------------------------------------------- |
| `enabled` | bool | yes      | `false` to hide all overlays; `true` to restore state |

**Returns:**

```json
{ "ok": true }
```

or

```json
{ "ok": false, "error": "overlays: \"enabled\" parameter is required" }
```

**Typical screenshot flow:**

```
1. call ext.slipstream.overlays(enabled: false)
2. take screenshot
3. call ext.slipstream.overlays(enabled: true)
```

---

## Events

Events are posted to the VM service `Extension` stream via
`dart:developer.postEvent`. Clients subscribe with `streamListen('Extension')`
and filter by `event.extensionKind`.

### `ext.slipstream.windowResized`

Fired whenever the window metrics change (resize, rotation, device pixel ratio
change). Backed by `WidgetsBindingObserver.didChangeMetrics`.

**Payload:**

```json
{
  "viewId": 0,
  "physicalWidth": 1170.0,
  "physicalHeight": 2532.0,
  "devicePixelRatio": 3.0,
  "logicalWidth": 390.0,
  "logicalHeight": 844.0
}
```

<!-- prettier-ignore-start -->
| Field | Type | Description |
| ----- | ---- | ----------- |
| `viewId` | int | Identifies the view that changed (relevant for multi-window apps) |
| `physicalWidth` / `physicalHeight` | double | Dimensions in physical pixels |
| `devicePixelRatio` | double | Physical pixels per logical pixel |
| `logicalWidth` / `logicalHeight` | double | Dimensions in logical pixels (`physical / devicePixelRatio`) |
<!-- prettier-ignore-end -->

### `ext.slipstream.routeChanged`

Fired whenever the registered router adapter's route changes. Requires
`SlipstreamAgent.init(router: ...)` to have been called.

`GoRouterAdapter` hooks this by listening to the `GoRouter` instance as a
`Listenable` (no hard `go_router` import required). The event fires once per
navigation, after the router has settled on the new path.

**Payload:**

```json
{ "path": "/podcast/787ae263b723" }
```

<!-- prettier-ignore-start -->
| Field | Type | Description |
| ----- | ---- | ----------- |
| `path` | String | The new current route path, as returned by `RouterAdapter.currentPath()` |
<!-- prettier-ignore-end -->
