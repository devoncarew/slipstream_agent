import 'package:flutter/widgets.dart';

/// Returns the first [Element] in the live widget tree that matches [finder]
/// and [value], or null if not found.
///
/// Supported finder types:
/// - `byKey` — matches a `ValueKey<String>` or `ValueKey<int>` (by string
///   representation)
/// - `byType` — matches the widget's `runtimeType.toString()` exactly
/// - `byText` — matches a [Text] widget whose `data` equals [value]
/// - `bySemanticsLabel` — matches a [Semantics] widget whose label equals
///   [value]
///
/// Returns null if no matching element is found.
Element? findElement({required String finder, required String value}) {
  Element? result;

  void visit(Element element) {
    if (result != null) return;
    if (_matches(element, finder, value)) {
      result = element;
      return;
    }
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);

  return result;
}

bool _matches(Element element, String finder, String value) {
  final Widget widget = element.widget;
  switch (finder) {
    case 'byKey':
      final Key? key = widget.key;
      if (key is ValueKey<String>) return key.value == value;
      if (key is ValueKey<int>) return key.value.toString() == value;
      return false;

    case 'byType':
      return widget.runtimeType.toString() == value;

    case 'byText':
      if (widget is Text) return widget.data == value;
      return false;

    case 'bySemanticsLabel':
      // Fast path: explicit Semantics widget with a plain-string label.
      if (widget is Semantics && widget.properties.label == value) return true;
      // Fallback: check the render-level semantics node. This covers widgets
      // that set semantics implicitly — ElevatedButton merges its child Text,
      // TextField maps InputDecoration.labelText, Semantics.attributedLabel,
      // etc. It is the same data source as ext.slipstream.get_semantics, so
      // the labels seen there and the values passed here are consistent.
      // Requires semantics to be enabled (ext.slipstream.enable_semantics).
      final node = element.renderObject?.debugSemantics;
      if (node != null && !node.isMergedIntoParent) {
        return node.getSemanticsData().label == value;
      }
      return false;

    default:
      return false;
  }
}
