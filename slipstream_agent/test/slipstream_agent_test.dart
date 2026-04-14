import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream_agent/slipstream_agent.dart';
import 'package:slipstream_agent/src/actions.dart';
import 'package:slipstream_agent/src/finder.dart';
import 'package:slipstream_agent/src/overlays.dart';
import 'package:slipstream_agent/src/semantics.dart';

void main() {
  group('SlipstreamAgent', () {
    testWidgets('init is idempotent', (tester) async {
      expect(kDebugMode, isTrue);
      SlipstreamAgent.init();
      SlipstreamAgent.init();
    });
  });

  group('findElement', () {
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

    testWidgets('bySemanticsLabel finds a Semantics widget by label',
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

    testWidgets('returns null when no widget matches', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox()),
        ),
      );

      expect(findElement(finder: 'byKey', value: 'nonexistent'), isNull);
      expect(findElement(finder: 'byType', value: 'NonExistentWidget'), isNull);
      expect(findElement(finder: 'byText', value: 'no such text'), isNull);
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

  group('tapElement', () {
    testWidgets('taps a button and fires its callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              key: const ValueKey('tap-me'),
              onPressed: () => tapped = true,
              child: const Text('Tap me'),
            ),
          ),
        ),
      );

      final element = findElement(finder: 'byKey', value: 'tap-me');
      expect(element, isNotNull);

      final error = await tapElement(element!);
      await tester.pumpAndSettle();

      expect(error, isNull);
      expect(tapped, isTrue);
    });

    testWidgets('returns null on success even for no-op press', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ElevatedButton(
              key: ValueKey('disabled'),
              onPressed: null,
              child: Text('Disabled'),
            ),
          ),
        ),
      );

      final element = findElement(finder: 'byKey', value: 'disabled');
      expect(element, isNotNull);

      // tapElement dispatches pointer events — it doesn't validate that the
      // button is enabled, so it still returns null.
      final error = await tapElement(element!);
      expect(error, isNull);
    });
  });

  group('setTextInElement', () {
    testWidgets('sets text on a TextField controller', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              key: const ValueKey('field'),
              controller: controller,
            ),
          ),
        ),
      );

      final element = findElement(finder: 'byKey', value: 'field');
      expect(element, isNotNull);

      final error = setTextInElement(element!, 'hello');
      expect(error, isNull);
      expect(controller.text, equals('hello'));
    });

    testWidgets('fires onChanged when text changes', (tester) async {
      String? changed;
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              key: const ValueKey('field'),
              controller: controller,
              onChanged: (v) => changed = v,
            ),
          ),
        ),
      );

      final element = findElement(finder: 'byKey', value: 'field');
      setTextInElement(element!, 'world');

      expect(changed, equals('world'));
    });

    testWidgets('does not fire onChanged when text is unchanged',
        (tester) async {
      var callCount = 0;
      final controller = TextEditingController(text: 'same');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              key: const ValueKey('field'),
              controller: controller,
              onChanged: (_) => callCount++,
            ),
          ),
        ),
      );

      final element = findElement(finder: 'byKey', value: 'field');
      setTextInElement(element!, 'same');

      expect(callCount, equals(0));
    });

    testWidgets('returns error when element has no EditableText',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text(
              'not editable',
              key: ValueKey('label'),
            ),
          ),
        ),
      );

      final element = findElement(finder: 'byKey', value: 'label');
      expect(element, isNotNull);

      final error = setTextInElement(element!, 'text');
      expect(error, isNotNull);
      expect(error, contains('set_text'));
    });
  });

  group('scrollElement', () {
    testWidgets('scrolls a ListView down', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              key: const ValueKey('list'),
              children: List.generate(
                50,
                (i) => SizedBox(height: 60, child: Text('Item $i')),
              ),
            ),
          ),
        ),
      );

      final element = findElement(finder: 'byKey', value: 'list');
      expect(element, isNotNull);

      final error =
          await scrollElement(element!, direction: 'down', pixels: 300);
      await tester.pump();

      expect(error, isNull);
    });

    testWidgets('scrolls up after scrolling down', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              key: const ValueKey('list'),
              children: List.generate(
                50,
                (i) => SizedBox(height: 60, child: Text('Item $i')),
              ),
            ),
          ),
        ),
      );

      final element = findElement(finder: 'byKey', value: 'list');
      await scrollElement(element!, direction: 'down', pixels: 600);
      await tester.pump();

      final error = await scrollElement(element, direction: 'up', pixels: 300);
      await tester.pump();

      expect(error, isNull);
    });

    testWidgets('returns error for unknown direction', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              key: const ValueKey('list'),
              children: List.generate(
                10,
                (i) => SizedBox(height: 60, child: Text('Item $i')),
              ),
            ),
          ),
        ),
      );

      final element = findElement(finder: 'byKey', value: 'list');
      // Direction validation is synchronous — no need for runAsync.
      final error =
          await scrollElement(element!, direction: 'diagonal', pixels: 100);
      expect(error, isNotNull);
      expect(error, contains('direction'));
    });

    testWidgets('returns error when element has no Scrollable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(key: ValueKey('box')),
          ),
        ),
      );

      final element = findElement(finder: 'byKey', value: 'box');
      // No Scrollable lookup is synchronous — no need for runAsync.
      final error =
          await scrollElement(element!, direction: 'down', pixels: 100);
      expect(error, isNotNull);
      expect(error, contains('scroll'));
    });
  });

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
        expect(node, contains('id'));
        expect(node, contains('role'));
        expect(node, contains('label'));
        expect(node, contains('value'));
        expect(node, contains('hint'));
        expect(node, contains('left'));
        expect(node, contains('top'));
        expect(node, contains('right'));
        expect(node, contains('bottom'));
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
      final buttonNodes = nodes!.where((n) => n['role'] == 'button').toList();
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
          nodes!.where((n) => n['role'] == 'textfield').toList();
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

      final buttonNodes = nodes!.where((n) => n['role'] == 'button').toList();
      expect(buttonNodes, isNotEmpty);

      final btn = buttonNodes.first;
      final left = btn['left'] as double;
      final top = btn['top'] as double;
      final right = btn['right'] as double;
      final bottom = btn['bottom'] as double;

      expect(right - left, greaterThan(0));
      expect(bottom - top, greaterThan(0));
    });
  });

  group('setOverlaysEnabled', () {
    setUp(() {
      // Ensure the banner override is in its default state before each test.
      WidgetsApp.debugAllowBannerOverride = true;
    });

    testWidgets('hides the debug banner when called with false', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      expect(WidgetsApp.debugAllowBannerOverride, isTrue);

      setOverlaysEnabled(false);
      await tester.pump();

      expect(WidgetsApp.debugAllowBannerOverride, isFalse);
    });

    testWidgets('restores the debug banner when called with true',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      setOverlaysEnabled(false);
      await tester.pump();
      expect(WidgetsApp.debugAllowBannerOverride, isFalse);

      setOverlaysEnabled(true);
      await tester.pump();
      expect(WidgetsApp.debugAllowBannerOverride, isTrue);
    });

    testWidgets('restores to false if banner was already hidden', (tester) async {
      WidgetsApp.debugAllowBannerOverride = false;
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      setOverlaysEnabled(false);
      await tester.pump();

      setOverlaysEnabled(true);
      await tester.pump();

      // Restored to the state it was in before the hide call.
      expect(WidgetsApp.debugAllowBannerOverride, isFalse);
    });

    testWidgets('restore is a no-op when no prior hide was called',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      // No hide call made — restore should leave the banner enabled.
      setOverlaysEnabled(true);
      await tester.pump();

      expect(WidgetsApp.debugAllowBannerOverride, isTrue);
    });
  });
}
