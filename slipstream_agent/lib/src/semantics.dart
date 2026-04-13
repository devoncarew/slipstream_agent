import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/rendering.dart';

/// Returns a flat list of visible semantics nodes as JSON-serializable maps,
/// plus an error string if the tree is unavailable.
///
/// Each map has the same fields as `SemanticNode` in the flutter_slipstream
/// package, so callers can deserialize directly into that type. Unlike the
/// out-of-process implementation, the [left] / [top] / [right] / [bottom]
/// values are accumulated screen-space coordinates in logical pixels (not each
/// node's unreliable local coordinate space).
///
/// Callers should invoke `ext.slipstream.enable_semantics` and wait for a
/// frame before calling this if the tree may not yet be enabled.
///
/// Returns `(null, errorMessage)` if semantics is not enabled or the tree is
/// empty.
(List<Map<String, Object?>>?, String?) getSemanticsNodes() {
  final owner = RendererBinding.instance.rootPipelineOwner.semanticsOwner;
  if (owner == null) return (null, 'semantics not enabled');
  final root = owner.rootSemanticsNode;
  if (root == null) {
    return (null, 'semantics tree empty — retry after a frame renders');
  }

  final entries = <_Entry>[];
  _collect(root, Matrix4.identity(), entries);

  final nodes = entries.where(_hasContent).map(_toMap).toList(growable: false);
  return (nodes, null);
}

// ---------------------------------------------------------------------------
// Tree traversal

class _Entry {
  _Entry(this.node, this.data, this.screenRect);
  final SemanticsNode node;
  final SemanticsData data;

  /// Bounding rectangle in logical screen coordinates.
  final Rect screenRect;
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
// Node → map

/// Converts an [_Entry] to a JSON-serializable map with the same field names
/// as `SemanticNode` in flutter_slipstream.
Map<String, Object?> _toMap(_Entry e) {
  final d = e.data;
  final f = d.flagsCollection;

  final bool? checked = f.isChecked == CheckedState.none
      ? null
      : f.isChecked == CheckedState.isTrue;
  final bool? toggled =
      f.isToggled == Tristate.none ? null : f.isToggled == Tristate.isTrue;
  final bool? selected =
      f.isSelected == Tristate.none ? null : f.isSelected == Tristate.isTrue;
  final bool? enabled =
      f.isEnabled == Tristate.none ? null : f.isEnabled == Tristate.isTrue;
  final bool focused = f.isFocused == Tristate.isTrue;

  return {
    'id': e.node.id,
    'role': _role(f),
    'label': d.label,
    'value': d.value,
    'hint': d.hint,
    'checked': checked,
    'toggled': toggled,
    'selected': selected,
    'enabled': enabled,
    'focused': focused,
    'actions': d.actions,
    'left': e.screenRect.left,
    'top': e.screenRect.top,
    'right': e.screenRect.right,
    'bottom': e.screenRect.bottom,
  };
}

// ---------------------------------------------------------------------------
// Helpers

String _role(SemanticsFlags f) {
  if (f.isButton) return 'button';
  if (f.isTextField) return 'textfield';
  if (f.isSlider) return 'slider';
  if (f.isLink) return 'link';
  if (f.isImage) return 'image';
  if (f.isHeader) return 'header';
  if (f.isChecked != CheckedState.none) return 'checkbox';
  if (f.isToggled != Tristate.none) return 'toggle';
  if (f.isInMutuallyExclusiveGroup) return 'radio';
  return '';
}

bool _hasContent(_Entry e) {
  final d = e.data;
  final f = d.flagsCollection;
  if (f.isChecked != CheckedState.none) return true;
  if (f.isToggled != Tristate.none) return true;
  if (f.isSelected == Tristate.isTrue) return true;
  if (f.isEnabled == Tristate.isFalse) return true;
  if (f.isFocused == Tristate.isTrue) return true;
  if (d.actions != 0) return true;
  if (_role(f).isNotEmpty) return true;
  return d.label.isNotEmpty || d.value.isNotEmpty || d.hint.isNotEmpty;
}
