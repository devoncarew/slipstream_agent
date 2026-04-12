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
      if (widget is Semantics) return widget.properties.label == value;
      return false;

    default:
      return false;
  }
}
