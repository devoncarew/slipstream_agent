import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream_agent/src/actions.dart';
import 'package:slipstream_agent/src/finder.dart';

void main() {
  group('findElement', () {
    // -----------------------------------------------------------------------
    // byKey

    testWidgets('byKey finds a widget with a ValueKey<String>', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(key: ValueKey('my-key')),
          ),
        ),
      );

      final element = findElement(finder: 'byKey', value: 'my-key');
      expect(element, isNotNull);
      expect(element!.widget.key, equals(const ValueKey('my-key')));
    });

    testWidgets('byKey finds a widget with a ValueKey<int>', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(key: ValueKey(42)),
          ),
        ),
      );

      final element = findElement(finder: 'byKey', value: '42');
      expect(element, isNotNull);
    });

    // -----------------------------------------------------------------------
    // byType

    testWidgets('byType finds a widget by runtime type name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('hello')),
          ),
        ),
      );

      final element = findElement(finder: 'byType', value: 'Text');
      expect(element, isNotNull);
      expect(element!.widget, isA<Text>());
    });

    // -----------------------------------------------------------------------
    // byText

    testWidgets('byText finds a Text widget by content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('hello world')),
          ),
        ),
      );

      final element = findElement(finder: 'byText', value: 'hello world');
      expect(element, isNotNull);
      expect((element!.widget as Text).data, equals('hello world'));
    });

    // -----------------------------------------------------------------------
    // bySemanticsLabel

    testWidgets('bySemanticsLabel finds an explicit Semantics widget by label',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              label: 'my-label',
              child: const SizedBox(),
            ),
          ),
        ),
      );

      final element =
          findElement(finder: 'bySemanticsLabel', value: 'my-label');
      expect(element, isNotNull);
    });

    testWidgets(
        'bySemanticsLabel finds an ElevatedButton by its implicit child-text label',
        (tester) async {
      // ElevatedButton merges its child Text into the semantics node label
      // via mergeAllDescendantsIntoThisNode — there is no explicit Semantics
      // widget with label='Submit' in the tree.
      final handle = RendererBinding.instance.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {},
              child: const Text('Submit'),
            ),
          ),
        ),
      );
      await tester.pump();

      final element = findElement(finder: 'bySemanticsLabel', value: 'Submit');
      handle.dispose();

      expect(element, isNotNull);
    });

    testWidgets(
        'bySemanticsLabel finds a TextField by its InputDecoration.labelText',
        (tester) async {
      final handle = RendererBinding.instance.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(labelText: 'Email'),
            ),
          ),
        ),
      );
      await tester.pump();

      final element = findElement(finder: 'bySemanticsLabel', value: 'Email');
      handle.dispose();

      expect(element, isNotNull);
    });

    testWidgets('bySemanticsLabel finds a widget with an attributedLabel',
        (tester) async {
      // Semantics.attributedLabel does not set properties.label, so the old
      // widget-property check would miss it; the render-level fallback covers
      // this case.
      final handle = RendererBinding.instance.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              attributedLabel: AttributedString('attr-label'),
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );
      await tester.pump();

      final element =
          findElement(finder: 'bySemanticsLabel', value: 'attr-label');
      handle.dispose();

      expect(element, isNotNull);
    });

    testWidgets(
        'bySemanticsLabel + setTextInElement works end-to-end on a TextField',
        (tester) async {
      // Regression: smoke test reported perform_set_text failing with
      // bySemanticsLabel even when get_semantics showed the label.
      final handle = RendererBinding.instance.ensureSemantics();

      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Search'),
            ),
          ),
        ),
      );
      await tester.pump();

      final element = findElement(finder: 'bySemanticsLabel', value: 'Search');
      handle.dispose();

      expect(element, isNotNull);
      final error = setTextInElement(element!, 'flutter');
      expect(error, isNull);
      expect(controller.text, equals('flutter'));
    });

    // -----------------------------------------------------------------------
    // Null / miss cases

    testWidgets('returns null when no widget matches', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox()),
        ),
      );

      expect(findElement(finder: 'byKey', value: 'nonexistent'), isNull);
      expect(findElement(finder: 'byType', value: 'NonExistentWidget'), isNull);
      expect(findElement(finder: 'byText', value: 'no such text'), isNull);
      expect(
          findElement(finder: 'bySemanticsLabel', value: 'no such label'),
          isNull);
    });

    testWidgets('unknown finder type returns null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('hello')),
        ),
      );

      expect(findElement(finder: 'byMagic', value: 'hello'), isNull);
    });
  });
}
