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
/// Unlike the out-of-process implementation, [SemanticsNodeInfo.screenRect]
/// values are accumulated screen-space coordinates in logical pixels (not each
/// node's unreliable local coordinate space).
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

  final entries = <_Entry>[];
  _collect(root, Matrix4.identity(), entries);

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

/// Recursively collects [SemanticsNode]s, skipping hidden and invisible ones.
///
/// [localToScreen] is the cumulative transform from the current node's local
/// coordinate space to screen space. Pass [Matrix4.identity] for the root.
void _collect(
  SemanticsNode node,
  Matrix4 localToScreen,
  List<_Entry> out,
) {
  if (node.isInvisible) return;

  final data = node.getSemanticsData();
  if (data.flagsCollection.isHidden) return;

  // node.transform maps FROM this node's local space TO the parent's space.
  // Composing: childLocalToScreen = parentLocalToScreen * childTransform
  final nodeTransform = node.transform;
  final Matrix4 childLocalToScreen = nodeTransform != null
      ? (localToScreen.clone()..multiply(nodeTransform))
      : localToScreen;

  out.add(_Entry(
      node, data, MatrixUtils.transformRect(childLocalToScreen, node.rect)));

  if (!node.mergeAllDescendantsIntoThisNode) {
    node.visitChildren((child) {
      _collect(child, childLocalToScreen, out);
      return true;
    });
  }
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
