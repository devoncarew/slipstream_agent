import 'package:flutter/widgets.dart';

/// Manages visibility of Flutter and Slipstream overlays.
///
/// Call with `false` to hide all overlays and save their current state.
/// Call with `true` to restore the previously saved state. If called with
/// `true` before any `false` call, it is a no-op.
///
/// Marks the widget tree dirty and schedules a frame, but does not await the
/// frame. Callers that need the change to be painted before proceeding (e.g.
/// before taking a screenshot) should wait for the next frame themselves.
void setOverlaysEnabled(bool enabled) {
  if (enabled) {
    _restore();
  } else {
    _save();
    _hideAll();
  }

  // Mark the tree dirty so the overlay change takes effect on the next frame.
  final root = WidgetsBinding.instance.rootElement;
  if (root != null) {
    _markNeedsRebuild(root);
  }
  WidgetsBinding.instance.scheduleFrame();
}

// ---------------------------------------------------------------------------
// Saved state

bool? _savedDebugBanner;

void _save() {
  _savedDebugBanner = WidgetsApp.debugAllowBannerOverride;
}

void _hideAll() {
  WidgetsApp.debugAllowBannerOverride = false;
}

void _restore() {
  if (_savedDebugBanner != null) {
    WidgetsApp.debugAllowBannerOverride = _savedDebugBanner!;
    _savedDebugBanner = null;
  }
}

// ---------------------------------------------------------------------------
// Helpers

/// Marks every element in the tree dirty so Flutter rebuilds after the overlay
/// state change.
void _markNeedsRebuild(Element element) {
  element.markNeedsBuild();
  element.visitChildren(_markNeedsRebuild);
}
