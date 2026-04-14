import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Synthesizes a tap at the center of [element]'s render box.
///
/// Returns null on success, or an error message on failure. The tap is
/// dispatched via [GestureBinding.handlePointerEvent], which performs hit
/// testing at the element's center position and routes the events through
/// Flutter's gesture recognizer system.
Future<String?> tapElement(Element element) async {
  final RenderBox? box = _findRenderBox(element);
  if (box == null) {
    return 'tap: no RenderBox found for element';
  }
  if (!box.hasSize) {
    return 'tap: RenderBox has no size (layout not complete)';
  }

  final Offset position = box.localToGlobal(box.size.center(Offset.zero));

  GestureBinding.instance.handlePointerEvent(
    PointerDownEvent(position: position),
  );
  GestureBinding.instance.handlePointerEvent(
    PointerUpEvent(position: position),
  );

  // Yield to the microtask queue so gesture recognizers fire synchronously
  // before we return.
  await Future<void>.microtask(() {});
  return null;
}

/// Sets the text content of the [EditableText] found in or below [element].
///
/// Walks [element]'s subtree to find an [EditableTextState] and sets its
/// controller's text to [text]. Returns null on success, or an error message
/// on failure.
String? setTextInElement(Element element, String text) {
  final EditableTextState? state = _findEditableTextState(element);
  if (state == null) {
    return 'set_text: no EditableText found in element subtree';
  }

  final String previous = state.widget.controller.text;
  state.widget.controller.text = text;
  // Mirror the framework's _formatAndSetValue behaviour: fire onChanged when
  // the text actually changed.  (TextInputFormatters are intentionally skipped
  // since we bypass the input pipeline.)
  if (text != previous) {
    state.widget.onChanged?.call(text);
  }
  return null;
}

/// Scrolls the [Scrollable] found at or below [element] by [pixels] in
/// [direction].
///
/// [direction] must be `"up"`, `"down"`, `"left"`, or `"right"`.
/// Returns null on success, or an error message on failure.
Future<String?> scrollElement(
  Element element, {
  required String direction,
  required double pixels,
}) async {
  final ScrollableState? state = _findScrollableState(element);
  if (state == null) {
    return 'scroll: no Scrollable found in element subtree';
  }

  final double delta = switch (direction) {
    'down' || 'right' => pixels,
    'up' || 'left' => -pixels,
    _ => double.nan,
  };
  if (delta.isNaN) {
    return 'scroll: unknown direction "$direction" — use up, down, left, right';
  }

  state.position.jumpTo(
    (state.position.pixels + delta).clamp(
      state.position.minScrollExtent,
      state.position.maxScrollExtent,
    ),
  );
  return null;
}

/// Scrolls the [Scrollable] at [scrollElement] until [targetElement] is
/// visible in the viewport.
///
/// Both elements must be located in the tree before calling this. Returns null
/// on success, or an error message on failure.
Future<String?> scrollUntilVisible({
  required Element targetElement,
  required Element scrollableElement,
}) async {
  final ScrollableState? scrollState = _findScrollableState(scrollableElement);
  if (scrollState == null) {
    return 'scroll_until_visible: no Scrollable found for scrollable finder';
  }

  // Attempt up to 20 scroll steps of 200px each to bring the target on screen.
  const int maxSteps = 20;
  const double stepPixels = 200.0;

  for (var i = 0; i < maxSteps; i++) {
    // Check if target is now visible.
    final RenderBox? targetBox = _findRenderBox(targetElement);
    if (targetBox != null && targetBox.hasSize) {
      final RenderAbstractViewport? viewport =
          RenderAbstractViewport.maybeOf(targetBox);
      if (viewport != null) {
        final RevealedOffset revealed =
            viewport.getOffsetToReveal(targetBox, 0.5);
        final double current = scrollState.position.pixels;
        final double target = revealed.offset;
        if ((current - target).abs() < 1.0) break; // already visible
        scrollState.position.jumpTo(
          target.clamp(
            scrollState.position.minScrollExtent,
            scrollState.position.maxScrollExtent,
          ),
        );
        break;
      }
    }
    // Target not yet laid out or no viewport — scroll down a step and retry.
    final double next = (scrollState.position.pixels + stepPixels).clamp(
      scrollState.position.minScrollExtent,
      scrollState.position.maxScrollExtent,
    );
    if (next == scrollState.position.pixels) break; // hit the end
    scrollState.position.jumpTo(next);
    // Wait for a frame so newly-scrolled widgets lay out.
    await SchedulerBinding.instance.endOfFrame;
  }

  return null;
}

/// Finds the first [ScrollableState] at or below [element].
ScrollableState? _findScrollableState(Element element) {
  if (element is StatefulElement && element.state is ScrollableState) {
    return element.state as ScrollableState;
  }
  ScrollableState? found;
  element.visitChildren((child) {
    if (found != null) return;
    found = _findScrollableState(child);
  });
  return found;
}

/// Finds the first [RenderBox] at or below [element].
RenderBox? _findRenderBox(Element element) {
  final RenderObject? ro = element.renderObject;
  if (ro is RenderBox) return ro;

  RenderBox? found;
  element.visitChildren((child) {
    if (found != null) return;
    found = _findRenderBox(child);
  });
  return found;
}

/// Finds the first [EditableTextState] at or below [element].
EditableTextState? _findEditableTextState(Element element) {
  if (element is StatefulElement && element.state is EditableTextState) {
    return element.state as EditableTextState;
  }
  EditableTextState? found;
  element.visitChildren((child) {
    if (found != null) return;
    found = _findEditableTextState(child);
  });
  return found;
}
