import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream_agent/src/semantics.dart';

void main() {
  group('getSemanticsNodes', () {
    testWidgets('returns nodes after semantics are enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Hello'),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Click me'),
                ),
              ],
            ),
          ),
        ),
      );

      final handle = RendererBinding.instance.ensureSemantics();
      await tester.pump();

      final (nodes, error) = getSemanticsNodes();
      handle.dispose();

      expect(error, isNull);
      expect(nodes, isNotNull);
      expect(nodes, isNotEmpty);
    });

    testWidgets('each node contains required fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {},
              child: const Text('Click me'),
            ),
          ),
        ),
      );

      final handle = RendererBinding.instance.ensureSemantics();
      await tester.pump();

      final (nodes, _) = getSemanticsNodes();
      handle.dispose();

      expect(nodes, isNotNull);
      expect(nodes!.isNotEmpty, isTrue);

      for (final node in nodes) {
        expect(node.id, isNot(equals(0)));
        expect(node.role, isNotNull);
        expect(node.label, isNotEmpty);
        expect(node.value, isNotNull);
        expect(node.hint, isNotNull);
        expect(node.screenRect, isNot(isEmpty));
      }
    });

    testWidgets('button node has button role', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {},
              child: const Text('Click me'),
            ),
          ),
        ),
      );

      final handle = RendererBinding.instance.ensureSemantics();
      await tester.pump();

      final (nodes, _) = getSemanticsNodes();
      handle.dispose();

      expect(nodes, isNotNull);
      final buttonNodes = nodes!.where((n) => n.role == 'button').toList();
      expect(buttonNodes, isNotEmpty);
    });

    testWidgets('text field node has textfield role', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextField(),
          ),
        ),
      );

      final handle = RendererBinding.instance.ensureSemantics();
      await tester.pump();

      final (nodes, _) = getSemanticsNodes();
      handle.dispose();

      expect(nodes, isNotNull);
      final textFieldNodes =
          nodes!.where((n) => n.role == 'textfield').toList();
      expect(textFieldNodes, isNotEmpty);
    });

    testWidgets('bounds are non-zero for visible widgets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {},
              child: const Text('Click me'),
            ),
          ),
        ),
      );

      final handle = RendererBinding.instance.ensureSemantics();
      await tester.pump();

      final (nodes, _) = getSemanticsNodes();
      handle.dispose();

      expect(nodes, isNotNull);

      final buttonNodes = nodes!.where((n) => n.role == 'button').toList();
      expect(buttonNodes, isNotEmpty);

      final rect = buttonNodes.first.screenRect;
      expect(rect.width, greaterThan(0));
      expect(rect.height, greaterThan(0));
    });

    testWidgets('inactive IndexedStack children are excluded', (tester) async {
      // Widgets on tabs that are not currently selected should not appear in
      // the semantics output.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IndexedStack(
              index: 0,
              children: [
                const Text('Active tab'),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Inactive button'),
                ),
              ],
            ),
          ),
        ),
      );

      final handle = RendererBinding.instance.ensureSemantics();
      await tester.pump();

      final (nodes, _) = getSemanticsNodes();
      handle.dispose();

      expect(nodes, isNotNull);
      final labels = nodes!.map((n) => n.label).toList();
      expect(labels, contains('Active tab'));
      expect(labels, isNot(contains('Inactive button')));
    });
  });
}
