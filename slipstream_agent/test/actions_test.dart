import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream_agent/src/actions.dart';
import 'package:slipstream_agent/src/finder.dart';

void main() {
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
      final error =
          await scrollElement(element!, direction: 'down', pixels: 100);
      expect(error, isNotNull);
      expect(error, contains('scroll'));
    });
  });
}
