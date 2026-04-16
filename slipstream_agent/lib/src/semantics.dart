import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/rendering.dart';

// ---------------------------------------------------------------------------
// Public API

/// A visible semantics node with screen-space bounds.
///
/// Fields mirror `SemanticNode` in `flutter_slipstream` so callers can
/// serialise with [toMap] and reconstruct that type on the server side.
class SemanticsNodeInfo {
  const SemanticsNodeInfo({
    required this.id,
    required this.role,
    required this.label,
    required this.value,
    required this.hint,
    required this.checked,
    required this.toggled,
    required this.selected,
    required this.enabled,
    required this.focused,
    required this.actions,
    required this.screenRect,
  });

  final int id;

  /// `"button"`, `"textfield"`, `"slider"`, `"link"`, `"image"`, `"header"`,
  /// `"checkbox"`, `"toggle"`, or `"radio"`.
  final String? role;

  final String label;
  final String value;
  final String hint;
  final bool? checked;
  final bool? toggled;
  final bool? selected;
  final bool? enabled;
  final bool focused;

  /// [SemanticsAction] bitmask.
  final int actions;

  /// Bounding rectangle in logical screen coordinates.
  final Rect screenRect;

  /// Returns a JSON-serializable map with the same field names as
  /// `SemanticNode` in `flutter_slipstream`.
  Map<String, Object?> toMap() => {
        'id': id,
        if (role != null) 'role': role,
        'label': label,
        'value': value,
        'hint': hint,
        if (checked != null) 'checked': checked,
        if (toggled != null) 'toggled': toggled,
        if (selected != null) 'selected': selected,
        if (enabled != null) 'enabled': enabled,
        'focused': focused,
        'actions': actions,
        'left': screenRect.left,
        'top': screenRect.top,
        'right': screenRect.right,
        'bottom': screenRect.bottom,
      };
}

/// Returns a flat list of visible semantics nodes with screen-space bounds,
/// plus an error string if the tree is unavailable.
///
/// [SemanticsNodeInfo.screenRect] values are in logical screen pixels.
/// Positions are obtained via [RenderBox.localToGlobal], which stays in logical
/// pixel space by not including the [RenderView]'s device-pixel-ratio scale.
/// This matches the coordinate system used by [Positioned.fromRect] in the
/// overlay.
///
/// Callers should invoke `ext.slipstream.enable_semantics` and wait for a
/// frame before calling this if the tree may not yet be enabled.
///
/// Returns `(null, errorMessage)` if semantics is not enabled or the tree is
/// empty.
(List<SemanticsNodeInfo>?, String?) getSemanticsNodes() {
  // TODO: Investigate how to move over to use rootPipelineOwner or
  // SemanticsBinding without losing the semantics tree.
  // ignore: deprecated_member_use
  final owner = RendererBinding.instance.pipelineOwner.semanticsOwner;
  if (owner == null) return (null, 'semantics not enabled');
  final root = owner.rootSemanticsNode;
  if (root == null) {
    return (null, 'semantics tree empty — retry after a frame renders');
  }

  // Walk the render tree rather than the semantics tree so we can use
  // RenderBox.localToGlobal for positions. Semantics transforms are in
  // physical pixels (RenderView._rootTransform scales by devicePixelRatio),
  // but localToGlobal excludes RenderView and stays in logical pixels.
  final entries = <_Entry>[];
  final seenIds = <int>{};
  for (final renderView in RendererBinding.instance.renderViews) {
    _collectFromRenderTree(renderView, entries, seenIds);
  }

  final nodes =
      entries.where(_hasContent).map(_toNodeInfo).toList(growable: false);

  return (nodes, null);
}

// ---------------------------------------------------------------------------
// Tree traversal

class _Entry {
  final SemanticsNode node;
  final SemanticsData data;

  /// Bounding rectangle in logical screen coordinates.
  final Rect screenRect;

  _Entry(this.node, this.data, this.screenRect);
}

/// Recursively walks the render tree collecting [SemanticsNode]s.
///
/// Uses [RenderBox.localToGlobal] for screen-space positions so that
/// coordinates stay in logical pixels, matching the overlay's coordinate
/// system. [seenIds] prevents duplicates when multiple render objects share
/// the same semantics node (e.g. sibling-merged nodes).
void _collectFromRenderTree(
  RenderObject renderObject,
  List<_Entry> out,
  Set<int> seenIds,
) {
  final semanticsNode = renderObject.debugSemantics;

  if (semanticsNode != null &&
      !semanticsNode.isMergedIntoParent &&
      !semanticsNode.isInvisible &&
      seenIds.add(semanticsNode.id)) {
    final data = semanticsNode.getSemanticsData();
    if (!data.flagsCollection.isHidden && renderObject is RenderBox) {
      final offset = renderObject.localToGlobal(Offset.zero);
      final screenRect = offset & renderObject.semanticBounds.size;
      out.add(_Entry(semanticsNode, data, screenRect));
    }
  }

  renderObject.visitChildrenForSemantics((child) {
    _collectFromRenderTree(child, out, seenIds);
  });
}

// ---------------------------------------------------------------------------
// Entry → SemanticsNodeInfo

SemanticsNodeInfo _toNodeInfo(_Entry entry) {
  final flags = entry.data.flagsCollection;

  return SemanticsNodeInfo(
    id: entry.node.id,
    role: _role(flags),
    label: entry.data.label,
    value: entry.data.value,
    hint: entry.data.hint,
    checked: flags.isChecked == CheckedState.none
        ? null
        : flags.isChecked == CheckedState.isTrue,
    toggled: flags.isToggled == Tristate.none
        ? null
        : flags.isToggled == Tristate.isTrue,
    selected: flags.isSelected == Tristate.none
        ? null
        : flags.isSelected == Tristate.isTrue,
    enabled: flags.isEnabled == Tristate.none
        ? null
        : flags.isEnabled == Tristate.isTrue,
    focused: flags.isFocused == Tristate.isTrue,
    actions: entry.data.actions,
    screenRect: entry.screenRect,
  );
}

// ---------------------------------------------------------------------------
// Helpers

String? _role(SemanticsFlags flags) {
  if (flags.isButton) return 'button';
  if (flags.isTextField) return 'textfield';
  if (flags.isSlider) return 'slider';
  if (flags.isLink) return 'link';
  if (flags.isImage) return 'image';
  if (flags.isHeader) return 'header';
  if (flags.isChecked != CheckedState.none) return 'checkbox';
  if (flags.isToggled != Tristate.none) return 'toggle';
  if (flags.isInMutuallyExclusiveGroup) return 'radio';

  return null;
}

bool _hasContent(_Entry entry) {
  final d = entry.data;
  final f = d.flagsCollection;

  if (f.isChecked != CheckedState.none) return true;
  if (f.isToggled != Tristate.none) return true;
  if (f.isSelected == Tristate.isTrue) return true;
  if (f.isEnabled == Tristate.isFalse) return true;
  if (f.isFocused == Tristate.isTrue) return true;
  if (d.actions != 0) return true;
  if (_role(f) != null) return true;

  return d.label.isNotEmpty || d.value.isNotEmpty || d.hint.isNotEmpty;
}
