import 'package:flutter/widgets.dart';

import 'ghost_overlay.dart';

/// Manages visibility of Slipstream overlays.
///
/// Call with `false` to hide all Slipstream overlays (the banner and command
/// log chips) before taking a screenshot. Call with `true` to restore them.
///
/// The Flutter debug banner is permanently disabled when the ghost overlay is
/// installed (on the first [ext.slipstream.ping] or [ext.slipstream.log]
/// call), and is not restored here.
///
/// Marks the widget tree dirty and schedules a frame, but does not await the
/// frame. Callers that need the change to be painted before proceeding (e.g.
/// before taking a screenshot) should wait for the next frame themselves.
void setOverlaysEnabled(bool enabled) {
  GhostOverlay.setVisible(enabled);

  // Mark the tree dirty so the overlay change takes effect on the next frame.
  final root = WidgetsBinding.instance.rootElement;
  if (root != null) {
    _markNeedsRebuild(root);
  }
  WidgetsBinding.instance.scheduleFrame();
}

// ---------------------------------------------------------------------------
// Helpers

/// Marks every element in the tree dirty so Flutter rebuilds after the overlay
/// state change.
void _markNeedsRebuild(Element element) {
  element.markNeedsBuild();
  element.visitChildren(_markNeedsRebuild);
}
